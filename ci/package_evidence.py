"""Preserve recovery, build, and integration-test evidence for the local delivery."""
import hashlib
from pathlib import Path
import zipfile

workspace = Path(__file__).resolve().parents[3]
target = workspace / "outputs/Build-and-test-evidence.zip"
folders = ["work/logs", "work/ci-evidence", "work/smoke-final-evidence", "work/pill-final-evidence",
           "work/death-evidence", "work/mode-clean-evidence", "work/story-final-evidence"]
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for folder in folders:
        for source in sorted((workspace / folder).rglob("*")):
            if source.is_file() and source.suffix in {".log", ".json", ".png", ".txt", ".pbxproj"}:
                archive.write(source, source.relative_to(workspace).as_posix())
digest = hashlib.file_digest(target.open("rb"), "sha256").hexdigest()
target.with_suffix(".zip.sha256").write_text(f"{digest}  {target.name}\n", encoding="ascii", newline="\n")
print(f"{target.name}: {target.stat().st_size} bytes, SHA256 {digest}")
