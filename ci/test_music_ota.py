"""Exercise Godot's real HTTP client, audio decoder and persistent cache."""
import argparse
import hashlib
import http.server
import io
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import wave


def wav_bytes(seconds):
    output = io.BytesIO()
    with wave.open(output, "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(8000)
        sound.writeframes(b"".join(
            struct.pack("<h", int(1000 * math.sin(2 * math.pi * 220 * n / 8000)))
            for n in range(int(seconds * 8000))
        ))
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--pack")
    args = parser.parse_args()
    sounds = {"1": wav_bytes(0.12), "2": wav_bytes(0.24),
              "3": (Path(args.project) / "audio/rack shotgun.ogg").read_bytes()}
    requests = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            requests.append(self.path)
            if self.path == "/offline":
                self.send_error(503)
                return
            if self.path.startswith("/audio/"):
                version = self.path.rsplit("/", 1)[1].split(".")[0]
                if version not in sounds:
                    self.send_error(404)
                    return
                body = sounds[version]
                mime = "audio/ogg" if version == "3" else "audio/wav"
            elif self.path.startswith("/manifest/"):
                version = self.path.rsplit("/", 1)[1]
                data = sounds.get(version, sounds["2"])
                audio_format = "ogg" if version == "3" else "wav"
                url = f"http://127.0.0.1:{self.server.server_port}/audio/{version}.{audio_format}"
                digest = hashlib.sha256(data).hexdigest()
                if version == "bad_hash":
                    url = f"http://127.0.0.1:{self.server.server_port}/audio/2.wav"
                    digest = "0" * 64
                elif version == "bad_url":
                    url = "https://example.invalid/music.wav"
                elif version == "missing":
                    digest = "f" * 64
                tracks = {} if version == "empty" else {
                    "batch_0": {"url": url, "sha256": digest, "format": audio_format, "loop": True}
                }
                body = json.dumps({"schema": 1, "tracks": tracks}).encode()
                mime = "application/json"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    with tempfile.TemporaryDirectory(prefix="buckshot-music-ota-") as cache:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = dict(os.environ, BUCKSHOT_OTA_TEST_URL=f"http://127.0.0.1:{server.server_port}",
                   BUCKSHOT_OTA_TEST_CACHE=cache.replace("\\", "/"))
        command = [args.godot, "--headless", "--audio-driver", "Dummy"]
        if args.pack:
            command.extend(["--main-pack", str(Path(args.pack).resolve())])
            script = str(Path(args.project).resolve() / "mobile/music_ota_test.gd")
        else:
            command.extend(["--path", args.project])
            script = "res://mobile/music_ota_test.gd"
        command.extend(["--script", script, "--", "--mobile-preview", "--ota-test"])
        try:
            result = subprocess.run(command, env=env, timeout=120, capture_output=True, text=True)
            print(result.stdout, end="")
            print(result.stderr, end="")
            if result.returncode or "MUSIC_OTA_RESULT PASS" not in result.stdout:
                raise SystemExit(result.returncode or 1)
            # One fetch for version 1, version 2, rejected hash, and cache repair.
            assert requests.count("/audio/1.wav") == 1, requests
            assert requests.count("/audio/2.wav") == 3, requests
            print("MUSIC_OTA_HTTP_CACHE_RESULT PASS")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    main()
