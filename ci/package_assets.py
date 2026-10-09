"""Create private asset and editable-project archives using ZIP's structured API."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def ignored(path):
    parts = path.parts
    if parts[0] == ".godot":
        return len(parts) < 2 or parts[1] != "imported"
    return path.name in {"gdre_export.log", "project.binary"} or path.suffix == ".tmp"


def archive(project, destination, assets_only):
    count = 0
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for source in sorted(project.rglob("*")):
            if not source.is_file():
                continue
            relative = source.relative_to(project)
            if ignored(relative):
                continue
            if assets_only and (source.suffix == ".gd" or relative.parts[0] == "mobile"
                                or relative.name in {"project.godot", "export_presets.cfg"}):
                continue
            output.write(source, relative.as_posix())
            count += 1
    digest = hashlib.file_digest(destination.open("rb"), "sha256").hexdigest()
    destination.with_suffix(destination.suffix + ".sha256").write_text(
        f"{digest}  {destination.name}\n", encoding="ascii")
    return {"archive": destination.name, "files": count,
            "bytes": destination.stat().st_size, "sha256": digest}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--assets-only", action="store_true")
    args = parser.parse_args()
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    print(json.dumps(archive(args.project, args.destination, args.assets_only), indent=2))


if __name__ == "__main__":
    main()

