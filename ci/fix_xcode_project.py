"""Quote legacy translation locale names in Godot's generated OpenStep project."""
import json
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
repairs = []


def quote_field(match):
    key, value = match.groups()
    if " " not in value or value.startswith('"'):
        return match.group(0)
    repairs.append({"field": key, "value": value})
    return f"{key} = {json.dumps(value)};"


lines = []
for line in source.splitlines(keepends=True):
    if "isa = PBXFileReference;" in line:
        line = re.sub(r"\b(name|path) = ([^;\n]+);", quote_field, line)
    lines.append(line)
path.write_text("".join(lines), encoding="utf-8", newline="\n")
print(json.dumps({"quoted_legacy_locale_fields": repairs}, indent=2))
