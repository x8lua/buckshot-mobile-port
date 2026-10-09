import json
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as file:
    info = plistlib.load(file)
executable = app / info["CFBundleExecutable"]
archs = subprocess.check_output(["xcrun", "lipo", "-archs", str(executable)], text=True).strip()
build_info = subprocess.check_output(["xcrun", "vtool", "-show-build", str(executable)], text=True)
assert archs == "arm64", archs
assert "platform IOS\n" in build_info, build_info
assert info["CFBundleIdentifier"] == "com.x8lua.buckshotmobile"
assert set(info["UIDeviceFamily"]) == {1, 2}, info.get("UIDeviceFamily")
assert info["MinimumOSVersion"] == "16.0", info.get("MinimumOSVersion")
orientations = info.get("UISupportedInterfaceOrientations", [])
assert orientations and all("Landscape" in orientation for orientation in orientations), orientations
packs = list(app.rglob("*.pck"))
assert packs and all(pack.stat().st_size > 1_000_000 for pack in packs)
print(json.dumps({"bundle_identifier": info["CFBundleIdentifier"], "architectures": archs,
                  "platform": "iPhoneOS", "minimum_ios": info["MinimumOSVersion"],
                  "device_families": info["UIDeviceFamily"], "orientations": orientations,
                  "packs": [{"name": pack.name, "bytes": pack.stat().st_size} for pack in packs],
                  "signed": False}, indent=2))

