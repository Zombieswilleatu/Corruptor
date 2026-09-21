#!/usr/bin/env bash
# Opens the protected-staging/responsive-monster balance sandbox directly.
set -euo pipefail
if [[ $# -ne 1 || ! -x "$1" ]]; then
  printf 'Usage: bash %s /path/to/Godot_4.7.2_executable\n' "$0" >&2
  exit 2
fi
u13_preview_exe=$1
u13_preview_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
u13_preview_version=$("$u13_preview_exe" --version)
if [[ ! "$u13_preview_version" =~ ^4\.7\.2\.stable([.[:space:]]|$) ]]; then
  printf 'The Vulture preview requires Godot 4.7.2 stable. Found: %s\n' "$u13_preview_version" >&2
  exit 1
fi
mkdir -p -- "$HOME/Downloads/Corruptor/Logs"
u13_preview_log=$(mktemp "$HOME/Downloads/Corruptor/Logs/u13-vulture-preview-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.log")
printf 'Project: %s\n' "$u13_preview_root"
printf 'MARCHER BALANCE · Monster tuning V21: Tumler charge.\nSinodek targets the nearest visible enemy within 600; one 25%% attempt per active round.\nFyra: 30%% charm per hit; pink hearts show temporary control.\nTumler: Sooge > Kopita > Fyra > Vulture. At range 400: +5 temporary Armor, ~0.5-second wind-up, then charge and shove bystanders aside. Target stays in place; enemy walls stop the charge. 15-second cooldown. 3 damage against marked prey, 2 against others (before Armor).\nKurchin: taunt radius 180; 6 Armor / 15 HP; 50%% deflection while Armor remains.\nWright: melee in the field; ranged 400 while guarding. Wrights walk to damaged structures and repair 1 HP every ~2 seconds at melee range, no Armor refill. Walls 16 HP / 4 Armor; towers 12 HP / 6 Armor. New arrivals can take over damaged, unguarded friendly structures.\nLemek: 5 Attack / 7 Armor / 10 HP.\nPenitent: 50%% block against ranged hits and ordinary Vulture melee hits.\nMuno: lunges every 7.5 seconds when a target is in range; grants one nonstacking absorbed hit that lasts until spent.\nVarn: 10%% poison chance; 1 HP immediately, then twice at ~2-second gaps; refreshes one effect.\nKopita: pulses at the start and ~10 seconds; heals 1 HP when needed, otherwise deals 2 damage.\nDotra: one guaranteed hide after his first 15 seconds on the field; full-speed hidden approach; 5 seconds untargetable after emergence; 5-damage ambush exposes nearby enemies to +1 damage for one round.\n15 protected slots per side; newborns wait one round; pressure-aware bot releases.\nVulture range 400; tower 600; Vulture +1 damage vs Butchers.\nSame-seed seat swap; 0.5x / 1x / 2x / 3x / 5x playback.\nContinuous mode prepares the next interval during playback (default ON).\nGoal-distance advance/fire starts ON. Staging offers 15 / 12 / Off comparisons.\nRun log: %s\n' "$u13_preview_log"
"$u13_preview_exe" --path "$u13_preview_root" --windowed --resolution 1440x900 \
  --rendering-method gl_compatibility res://Prototype/U13/U13VulturePreview.tscn 2>&1 | tee "$u13_preview_log"
