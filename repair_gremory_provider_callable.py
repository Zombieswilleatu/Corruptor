from pathlib import Path
import os


path = Path("Scripts/Sim/BotResolutionDoctrine.gd")

if not path.is_file():
    raise SystemExit(f"REFUSED: missing expected file: {path}")

data = path.read_bytes()
newline = b"\r\n" if b"\r\n" in data else b"\n"

old_lf = b'''\tdecisions["gremory_provider"] = Callable(
\t\tBotResolutionDoctrineData,
\t\t"current_gremory_choices"
\t)
'''

new_lf = b'''\tdecisions["gremory_provider"] = current_gremory_choices
'''

old = old_lf.replace(b"\n", newline)
new = new_lf.replace(b"\n", newline)

if data.count(new) == 1 and data.count(old) == 0:
    raise SystemExit("REFUSED: direct Gremory provider callable is already installed")

if data.count(old) != 1:
    raise SystemExit(
        "REFUSED: expected invalid Gremory provider constructor exactly once, "
        f"found {data.count(old)}"
    )

updated = data.replace(old, new, 1)

if b"BotResolutionDoctrineData" in updated:
    raise SystemExit(
        "REFUSED: BotResolutionDoctrineData remains in BotResolutionDoctrine.gd"
    )

temporary = path.with_name(path.name + ".tmp")

if temporary.exists():
    raise SystemExit(f"REFUSED: temporary path already exists: {temporary}")

temporary.write_bytes(updated)
os.replace(temporary, path)

print("Repaired the Gremory provider callable self-reference.")
print("No simulation logic, oracle, golden file, or Git ref was changed.")
