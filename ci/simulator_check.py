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
    container = Path(run("get_app_container", udid, bundle_id, "data").strip())
    logs = []
    for index, logfile in enumerate(container.rglob("godot*.log")):
        target = evidence / f"{prefix.lower()}-runtime-{index}.log"
        shutil.copy2(logfile, target)
        logs.append(target.name)
        content = logfile.read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR:" in content or "ERROR: Failed to load" in content:
            raise RuntimeError(f"Blocking runtime error in {target.name}")
    text = subprocess.check_output(["swift", "ci/verify_screenshot.swift", str(screenshot)], text=True)
    results.append({"device": device["name"], "udid": udid, "launch": launch.strip(),
                    "screenshot": screenshot.name, "runtime_logs": logs, "recognized_text": text.strip(),
                    "verification": "App launch and original title rendered; no real-device performance claim"})
    run("terminate", udid, bundle_id)
    run("shutdown", udid)
(evidence / "simulator-results.json").write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))

