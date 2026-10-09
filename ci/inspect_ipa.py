"""Independently inspect an IPA on Windows without Xcode."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import zipfile


def inspect(path):
    with zipfile.ZipFile(path) as archive:
        root = "Payload/BuckshotMobile.app/"
        names = archive.namelist()
        assert archive.testzip() is None, "ZIP CRC mismatch"
        info = plistlib.loads(archive.read(root + "Info.plist"))
        executable = archive.read(root + info["CFBundleExecutable"])
        magic, cpu, subtype, kind, commands, command_bytes, flags, reserved = struct.unpack_from("<8I", executable)
        assert magic == 0xFEEDFACF and cpu == 0x0100000C and kind == 2, "Not an ARM64 Mach-O executable"
        offset = 32
        platforms = []
        for _ in range(commands):
            command, length = struct.unpack_from("<II", executable, offset)
            assert length >= 8 and offset + length <= len(executable)
            if command == 0x32:
                platforms.append(struct.unpack_from("<I", executable, offset + 8)[0])
            offset += length
        assert 2 in platforms and 7 not in platforms, "Not an iPhoneOS device binary"
        assert info["CFBundleIdentifier"] == "com.x8lua.buckshotmobile"
        assert info["MinimumOSVersion"] == "16.0"
        assert set(info["UIDeviceFamily"]) == {1, 2}
        orientations = info["UISupportedInterfaceOrientations"]
        assert orientations and all("Landscape" in value for value in orientations)
        packs = [item for item in archive.infolist() if item.filename.startswith(root) and item.filename.endswith(".pck")]
        assert packs and all(item.file_size > 1_000_000 for item in packs)
        assert not any("/_CodeSignature/" in name or name.endswith("embedded.mobileprovision") for name in names)
        return {"ipa": path.name, "bytes": path.stat().st_size,
                "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest(),
                "zip_crc": "passed", "architecture": "arm64", "macho_platform": "iPhoneOS (2)",
                "bundle_id": info["CFBundleIdentifier"], "minimum_ios": info["MinimumOSVersion"],
                "device_families": info["UIDeviceFamily"], "orientations": orientations,
                "packs": [{"name": item.filename, "bytes": item.file_size} for item in packs],
                "apple_signature_directory": False, "provisioning_profile": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = json.dumps(inspect(args.ipa), indent=2)
    if args.output:
        args.output.write_text(report + "\n", encoding="utf-8", newline="\n")
    print(report)
