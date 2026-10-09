import json
from pathlib import Path
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
for prefix in ("iPhone", "iPad"):
    device = next((item for item in reversed(eligible) if item["name"].startswith(prefix)), None)
    if device is None:
        raise RuntimeError(f"No available {prefix} simulator")
    udid = device["udid"]
    if device["state"] != "Booted":
        run("boot", udid)
    run("bootstatus", udid, "-b")
    run("install", udid, app)
    launch = run("launch", "--terminate-running-process", udid, bundle_id)
    time.sleep(35)
    screenshot = evidence / f"{prefix.lower()}-simulator.png"
    run("io", udid, "screenshot", str(screenshot))
    text = subprocess.check_output(["swift", "ci/verify_screenshot.swift", str(screenshot)], text=True)
    results.append({"device": device["name"], "udid": udid, "launch": launch.strip(),
                    "screenshot": screenshot.name, "recognized_text": text.strip(),
                    "verification": "App launch and original title rendered; no real-device performance claim"})
    run("terminate", udid, bundle_id)
    run("shutdown", udid)
(evidence / "simulator-results.json").write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))

