from pathlib import Path
import os


path = Path("Scripts/Sim/BotResolutionDoctrine.gd")

if not path.is_file():
    raise SystemExit(f"REFUSED: missing expected file: {path}")

data = path.read_bytes()
newline = b"\r\n" if b"\r\n" in data else b"\n"

old_lf = b'''\tdecisions["gremory_provider"] = current_gremory_choices
'''

new_lf = b'''\t# Static functions have no self in Godot 4.2. Bind the Callable to
\t# this cached script resource instead of an unqualified method member.
\tdecisions["gremory_provider"] = Callable(
\t\tload("res://Scripts/Sim/BotResolutionDoctrine.gd"),
\t\t"current_gremory_choices"
\t)
'''

old = old_lf.replace(b"\n", newline)
new = new_lf.replace(b"\n", newline)

if data.count(new) == 1 and data.count(old) == 0:
    raise SystemExit("REFUSED: script-bound Gremory provider is already installed")

if data.count(old) != 1:
    raise SystemExit(
        "REFUSED: expected direct Gremory provider reference exactly once, "
        f"found {data.count(old)}"
    )

if data.count(b"static func current_gremory_choices(") != 1:
    raise SystemExit(
        "REFUSED: expected current_gremory_choices exactly once, found "
        f"{data.count(b'static func current_gremory_choices(')}"
    )

updated = data.replace(old, new, 1)
temporary = path.with_name(path.name + ".tmp")

if temporary.exists():
    raise SystemExit(f"REFUSED: temporary path already exists: {temporary}")

temporary.write_bytes(updated)
os.replace(temporary, path)

print("Bound the Gremory provider Callable to its script resource.")
print("No simulation logic, oracle, golden file, or Git ref was changed.")
