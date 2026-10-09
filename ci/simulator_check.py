import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

app = str(Path(sys.argv[1]).resolve())
evidence = Path("build/evidence")
bundle_id = "com.x8lua.buckshotmobile"


def run(*args):
    result = subprocess.run(["xcrun", "simctl", *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"simctl {args}: {result.stderr}")
    return result.stdout


devices = json.loads(run("list", "devices", "available", "--json"))["devices"]
eligible = [device for runtime, group in devices.items() if "iOS" in runtime
            for device in group if device.get("isAvailable")]
results = []
subprocess.run(["swiftc", "ci/verify_screenshot.swift", "-o", "build/verify-screenshot"], check=True)
for prefix in ("iPhone", "iPad"):
    device = next((item for item in reversed(eligible) if item["name"].startswith(prefix)), None)
    if device is None:
        raise RuntimeError(f"No available {prefix} simulator")
    udid = device["udid"]
    print(f"Booting {device['name']}", flush=True)
    if device["state"] != "Booted":
        run("boot", udid)
    run("bootstatus", udid, "-b")
    run("install", udid, app)
    launch = run("launch", "--terminate-running-process", udid, bundle_id)
    print(launch.strip(), flush=True)
    screenshot = evidence / f"{prefix.lower()}-simulator.png"
    recognized = None
    started = time.monotonic()
    for attempt in range(40):
        time.sleep(15)
        run("io", udid, "screenshot", str(screenshot))
        recognition = subprocess.run(["build/verify-screenshot", str(screenshot)], text=True, capture_output=True)
        print(f"{prefix} screenshot attempt {attempt + 1}, elapsed {time.monotonic() - started:.0f}s, title={recognition.returncode == 0}", flush=True)
        if recognition.returncode == 0:
            recognized = recognition.stdout
            break
    container = Path(run("get_app_container", udid, bundle_id, "data").strip())
    logs = []
    for index, logfile in enumerate(container.rglob("godot*.log")):
        target = evidence / f"{prefix.lower()}-runtime-{index}.log"
        shutil.copy2(logfile, target)
        logs.append(target.name)
        content = logfile.read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR:" in content or "ERROR: Failed to load" in content:
            raise RuntimeError(f"Blocking runtime error in {target.name}")
    if recognized is None:
        raise RuntimeError(f"{prefix} never rendered the original menu title within the launch deadline")
    results.append({"device": device["name"], "udid": udid, "launch": launch.strip(),
                    "screenshot": screenshot.name, "runtime_logs": logs, "recognized_text": recognized.strip(),
                    "launch_wait_seconds": round(time.monotonic() - started),
                    "verification": "App launch and original title rendered; no real-device performance claim"})
    run("terminate", udid, bundle_id)
    run("shutdown", udid)
    (evidence / "simulator-results.json").write_text(json.dumps(results, indent=2))
(evidence / "simulator-results.json").write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))

