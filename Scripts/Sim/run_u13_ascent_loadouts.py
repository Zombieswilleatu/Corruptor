#!/usr/bin/env python3
"""Prepare a paired Ascent castle-loadout screen; games require --run.

This screens ordinary five-slot self-play, not native Ascent progression.
Only the new runner is installed; freeze() captures the local simulation build.
"""
import argparse
from collections import Counter
from copy import deepcopy
import hashlib
from itertools import combinations
import json
import os
from pathlib import Path
import subprocess
import sys
import time

VERSION = "U13_ASCENT_LOADOUT_SCREEN_V2_DUPLICATES"
BASE = ["Keep", "Stockpile", "SummoningCircle", "SiegeEngine", "Bastion"]
NAMESPACE = "u13-ascent-loadout-screen-20260929"
PROFILE_NAMES = ("control", "stock_engine", "stock_bastion",
                 "circle_engine", "circle_bastion", "engine_bastion")
SCOPE = (
    "Paired five-slot, three-active-castle self-play screen. Only one Lord's "
    "castle loadout changes per treatment. No stat or doctrine edits. "
    "Not native Ascent balance: retinue, inheritance, player three-slot domains, "
    "all reserve combinations and full positional permutations need separate validation. "
    "Shared controls are reused; comparisons are correlated. One repeat is "
    "screening evidence, not a reliable optimum or a 50% balance verdict."
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(value):
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(raw).hexdigest()


def write_json(path, value):
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def profiles():
    result = {
        name: ["Keep", *pair, *[kind for kind in BASE[1:] if kind not in pair]]
        for name, pair in zip(PROFILE_NAMES, combinations(BASE[1:], 2))
    }
    # Each duplicate is a one-slot replacement of a single-copy profile.
    # Hold the reserve pair fixed for the second-copy comparison.
    result.update(
        double_stock=["Keep", "Stockpile", "Stockpile", "SiegeEngine", "Bastion"],
        double_circle=["Keep", "SummoningCircle", "SummoningCircle", "SiegeEngine", "Bastion"],
        double_engine=["Keep", "SiegeEngine", "SiegeEngine", "SummoningCircle", "Bastion"],
        double_bastion=["Keep", "Bastion", "Bastion", "SummoningCircle", "SiegeEngine"])
    require(len(result) == 10, "Expected ten active-trio profiles")
    require(len({tuple(sorted(order[:3])) for order in result.values()}) == 10,
            "Active trios must be distinct")
    for order in result.values():
        require(len(order) == 5 and order[0] == "Keep" and order.count("Keep") == 1,
                "Expected Keep and four non-Keep castles")
        require(all(kind in BASE and count <= 2 for kind, count in Counter(order).items()),
                "Illegal duplicate castle loadout")
    return result


def make_config(repeats, namespace, smoke):
    from run_u13_lord_balance import balance_cases
    from u13_pysim.opening import LORDS

    require(len(LORDS) == 9 and len(set(LORDS)) == 9, "Review design for changed roster")
    source = balance_cases(repeats, namespace)
    originals = {}
    for spec in source:
        left, right = spec["setup"]["lords"]
        if left != right:
            originals[(spec["repeat"], left, right)] = spec
    require(len(originals) == 72 * repeats, "Unexpected installed matchup generator")
    orders = profiles()
    require(orders["control"] == BASE, "Invalid control order")
    cases, pairs = [], []
    keys = sorted(originals, key=lambda key: (key[0], digest([namespace, key[1:]])))
    for repeat, left, right in keys:
        if smoke and {left, right} != {"Deimos", "Orias"}:
            continue
        original = deepcopy(originals[(repeat, left, right)])
        require(original["setup"]["castles"] == [BASE, BASE],
                "Installed control loadout changed; review before running")
        baseline = deepcopy(original)
        baseline["name"] = f"control_{left.lower()}_{right.lower()}_{repeat:02d}"
        cases.append(baseline)
        for profile, loadout in orders.items():
            if profile == "control":
                continue
            for seat, lord in enumerate((left, right)):
                if smoke and lord != "Deimos":
                    continue
                candidate = deepcopy(original)
                candidate["name"] = f"{profile}_s{seat}_{left.lower()}_{right.lower()}_{repeat:02d}"
                candidate["setup"]["castles"][seat] = loadout[:]
                cases.append(candidate)
                pair = dict(control=baseline["name"], treatment=candidate["name"],
                            lord=lord, opponent=(right if seat == 0 else left),
                            seat=seat, profile=profile, repeat=repeat, comparator="control")
                pairs.append(pair)
                # Stock/Circle duplicates already differ by one slot from control.
                # These two extra comparisons reuse games, adding no simulation cost.
                parent = {"double_engine": "stock_engine",
                          "double_bastion": "stock_bastion"}.get(profile)
                if parent:
                    pairs.append(dict(pair, comparator=parent,
                        control=f"{parent}_s{seat}_{left.lower()}_{right.lower()}_{repeat:02d}"))
    require(len(cases) == (20 if smoke else 1368) * repeats, "Wrong unique game count")
    require(len(pairs) == (22 if smoke else 1584) * repeats, "Wrong pairing count")
    require(len({s["name"] for s in cases}) == len(cases), "Duplicate case name")
    by_name = {s["name"]: s for s in cases}
    for pair in pairs:
        control, treatment = by_name[pair["control"]], by_name[pair["treatment"]]
        restored = deepcopy(treatment["setup"])
        restored["castles"][pair["seat"]] = control["setup"]["castles"][pair["seat"]][:]
        require(restored == control["setup"], "Treatment changed more than focal castles")
        if pair["profile"].startswith("double_") and (
                pair["comparator"] != "control" or pair["profile"] in ("double_stock", "double_circle")):
            before = control["setup"]["castles"][pair["seat"]]
            after = treatment["setup"]["castles"][pair["seat"]]
            require(before[3:] == after[3:], "Second-copy comparison changed reserve castles")
            require(sum(a != b for a, b in zip(before, after)) == 1,
                    "Second-copy comparison must change exactly one slot")
        reverse_key = (pair["repeat"], *reversed(control["setup"]["lords"]))
        require(originals[reverse_key]["setup"]["seed"] == control["setup"]["seed"],
                "Seat-swapped games must share the seed")
    return dict(version=VERSION, scope=SCOPE, namespace=namespace, repeats=repeats,
                smoke=smoke, profiles=orders, cases=cases, pairs=pairs)


def validate_openings(config):
    from u13_pysim.power_match import PowerMatch

    decks, checked = {}, 0
    for spec in config["cases"]:
        match = PowerMatch(spec["setup"])
        world = match._state["world"]
        entities = world["entities"]["entities"]
        for seat, expected in enumerate(spec["setup"]["castles"]):
            castles = sorted(
                (e["attributes"] for e in entities if e["kind"] == "castle" and e["owner"] == seat),
                key=lambda a: a["castle_slot"])
            require([a["castle_type"] for a in castles] == expected, "Setup ignored castle ordering")
            require(all(a["construction_state"] == ("active" if slot < 3 else "unbuilt")
                        for slot, a in enumerate(castles)), "Opening active slots changed")
            require(all(a["integrity"] == (a["max_integrity"] if slot < 3 else 0)
                        for slot, a in enumerate(castles)), "Opening integrity changed")
        key = spec["setup"]["seed"], tuple(spec["setup"]["lords"])
        deck = digest(world["data"]["card_zones"])
        require(decks.setdefault(key, deck) == deck, "Treatment changed opening card shuffle")
        checked += 1
    return checked


def checked_config(output):
    from run_u13_lord_balance import verify_frozen

    verify_frozen(output)
    config = json.loads((output / "loadout-config.json").read_text(encoding="utf-8"))
    expected = make_config(config["repeats"], config["namespace"], config["smoke"])
    require(config == expected, "Experiment config changed; refusing to mix results")
    return config


def small_record(record):
    if record["status"] != "complete":
        return dict(status="failed", error=record.get("error"))
    game = record["semantic"]
    winner = game["outcome"]["winner"]
    require(winner in (-1, 0, 1), "Unknown outcome winner")
    powers, actions, rejected = [Counter(), Counter()], [Counter(), Counter()], [0, 0]
    for entry in record.get("trace", []):
        seat = entry["view"]["player_id"]
        decision = entry["decision"]
        powers[seat].update(p["power_id"] for p in decision["plan"]["powers"])
        actions[seat].update([decision["plan"]["order"].get("action", "Pass")])
        rejected[seat] += len(decision.get("rejected_previews", []))
    return dict(status="complete", winner=winner, rounds=game["rounds"],
                route=game["outcome"].get("win_by", "unknown"), powers=powers,
                actions=actions, rejected_previews=rejected)


def summarize(output, config):
    from u13_doctrine.survey import read_record

    records, missing = {}, []
    manifest_path = output / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        from u13_doctrine.diagnostics import fingerprint
        require(manifest.get("case_list_sha256") == fingerprint(config["cases"]),
                "Report manifest does not match case list")
        for spec in config["cases"]:
            path = output / "games" / (spec["name"] + ".json.gz")
            if path.exists():
                records[spec["name"]] = small_record(read_record(path, manifest, spec))
            else:
                missing.append(spec["name"])
    else:
        missing = [s["name"] for s in config["cases"]]
    rows, excluded = {}, []
    for pair in config["pairs"]:
        key = (pair["lord"], pair["profile"], pair["comparator"])
        row = rows.setdefault(key, dict(
            lord=key[0], profile=key[1], comparator=key[2], scheduled=0, paired=0, control_wins=0,
            treatment_wins=0, wins_gained=0, wins_lost=0, round_delta=0,
            control_rounds=0, treatment_rounds=0,
            control_powers=Counter(), treatment_powers=Counter(),
            control_actions=Counter(), treatment_actions=Counter(),
            control_rejected=0, treatment_rejected=0,
            control_win_routes=Counter(), treatment_win_routes=Counter(),
            seats={}, opponents={}))
        row["scheduled"] += 1
        base, treatment = records.get(pair["control"]), records.get(pair["treatment"])
        if (not base or not treatment or base["status"] != "complete"
                or treatment["status"] != "complete"
                or base["winner"] == -1 or treatment["winner"] == -1):
            excluded.append(pair)
            continue
        seat = pair["seat"]
        bw, tw = int(base["winner"] == seat), int(treatment["winner"] == seat)
        row["paired"] += 1
        row["control_wins"] += bw
        row["treatment_wins"] += tw
        row["wins_gained"] += int(tw > bw)
        row["wins_lost"] += int(tw < bw)
        row["round_delta"] += treatment["rounds"] - base["rounds"]
        for label, item, win in (("control", base, bw), ("treatment", treatment, tw)):
            row[label + "_rounds"] += item["rounds"]
            row[label + "_powers"].update(item["powers"][seat])
            row[label + "_actions"].update(item["actions"][seat])
            row[label + "_rejected"] += item["rejected_previews"][seat]
            if win:
                row[label + "_win_routes"].update([item["route"]])
        for group, category in (("seats", str(seat)), ("opponents", pair["opponent"])):
            cell = row[group].setdefault(category, dict(paired=0, control_wins=0, treatment_wins=0))
            cell["paired"] += 1
            cell["control_wins"] += bw
            cell["treatment_wins"] += tw
    for row in rows.values():
        n = row["paired"]
        row["paired_delta_pp"] = round(100 * (row["treatment_wins"] - row["control_wins"]) / n, 2) if n else None
        row["mean_round_delta"] = round(row["round_delta"] / n, 2) if n else None
    failures = [dict(name=name, error=r.get("error"))
                for name, r in records.items() if r["status"] != "complete"]
    unresolved = [name for name, r in records.items()
                  if r["status"] == "complete" and r["winner"] == -1]
    report = dict(scope=SCOPE, requested=len(config["cases"]), saved=len(records),
                  missing=missing, failures=failures, unresolved=unresolved,
                  excluded_pairs=excluded, rows=[rows[k] for k in sorted(rows)])
    write_json(output / "loadout-report.json", report)
    lines = ["# Ascent loadout screen", "", SCOPE, "",
             f"Saved {len(records)}/{len(config['cases'])}; failures {len(failures)}; "
             f"unresolved {len(unresolved)}; excluded pairs {len(excluded)}.", "",
             "Control wins are recalculated on the exact completed treatment pairs.",
             "Gained/lost means a loss-to-win / win-to-loss flip on the same seed and seat.",
             "Rates across rows share controls and must not be pooled as independent games.",
             "Comparator identifies the reference loadout. Most rows use the original control.",
             "Extra double_engine/stock_engine and double_bastion/stock_bastion rows isolate",
             "the second copy with identical reserve castles. Double Stockpile and Circle",
             "already have identical reserves to the original control.", "",
             "| Lord | Active trio profile | Comparator | Pairs | Reference wins | Test wins | Gained | Lost | Delta pp | Round delta |",
             "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for row in report["rows"]:
        lines.append("| " + " | ".join(str(row[k]) for k in (
            "lord", "profile", "comparator", "paired", "control_wins", "treatment_wins",
            "wins_gained", "wins_lost", "paired_delta_pp", "mean_round_delta")) + " |")
    lines += ["", "Power declarations, action selections, win routes, rejected previews, "
              "seat/opponent breakdowns, failures and missing cases are in loadout-report.json.",
              "Declarations are not proof that a power resolved successfully.",
              "Recheck shortlisted profiles on fresh seeds, then in native Ascent before adoption.", ""]
    (output / "loadout-report.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"PAIRED REPORT: {output / 'loadout-report.md'}", flush=True)
    return not (missing or failures or unresolved)


def frozen_main(args, output):
    from run_u13_lord_balance import verify_frozen, Tee

    verify_frozen(output)
    if args.internal == "prepare":
        config = make_config(args.repeats, args.namespace, args.smoke)
        checked = validate_openings(config)
        write_json(output / "loadout-config.json", config)
        write_json(output / "loadout-preflight.json", dict(openings_checked=checked,
                   cases_sha256=digest(config["cases"]), config_sha256=digest(config)))
        print(f"PREPARED: {len(config['cases'])} games, {len(config['pairs'])} paired comparisons."
              f"\nReports: {output}\nNo games have started.", flush=True)
        return 0
    config = checked_config(output)
    if args.internal == "summarize":
        summarize(output, config)
        return 0
    from u13_doctrine.survey import run
    with (output / "run.log").open("a", encoding="utf-8") as log:
        old_out, old_err = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = Tee(old_out, log), Tee(old_err, log)
        try:
            result = run(Path(__file__).resolve().parents[2], output,
                         repeats=config["repeats"], workers=args.workers,
                         namespace=config["namespace"], worker_batch_size=args.worker_batch_size,
                         case_list=config["cases"])
            okay = summarize(output, config)
            return int(bool(result["summary"]["failed"]) or not okay)
        finally:
            sys.stdout, sys.stderr = old_out, old_err


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--resume", type=Path)
    parser.add_argument("--run", action="store_true", help="Execute games; default only prepares")
    parser.add_argument("--smoke", action="store_true", help="20 games: Deimos vs Orias, all ten profiles, both seats")
    parser.add_argument("--summarize", action="store_true", help="Report/package existing complete or partial results")
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--namespace", default=NAMESPACE, help="Change for fresh-seed confirmation")
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument("--worker-batch-size", type=int, default=12)
    parser.add_argument("--internal", choices=("prepare", "run", "summarize"), help=argparse.SUPPRESS)
    args = parser.parse_args()
    require(args.workers > 0 and args.repeats > 0 and args.worker_batch_size > 0,
            "workers, repeats and batch size must be positive")
    require(not (args.output and args.resume), "Choose output OR resume")
    require(not (args.run and args.summarize), "Choose run OR summarize")
    require(not args.summarize or args.resume, "Summarize requires --resume")
    require(not args.resume or not args.smoke, "Resume uses the existing configuration; omit --smoke")
    if args.internal:
        return frozen_main(args, args.output.resolve())

    from run_u13_lord_balance import freeze, verify_frozen, package
    root = Path(__file__).resolve().parents[2]
    mode = "duplicates-smoke" if args.smoke else "duplicates-screen"
    output = (args.resume or args.output or Path.home() / "Downloads/Corruptor/Balance" /
              time.strftime("u13-loadouts-" + mode + "-%Y%m%d-%H%M%S")).resolve()
    env = dict(os.environ)
    env.pop("PYTHONPATH", None)
    env["PYTHONNOUSERSITE"] = "1"
    if args.resume:
        verify_frozen(output)
        frozen = output / "source"
    else:
        output.mkdir(parents=True, exist_ok=False)
        frozen = freeze(root, output)
    runner = frozen / "Scripts/Sim" / Path(__file__).name

    def invoke(action):
        command = [sys.executable, "-u", str(runner), "--internal", action,
                   "--output", str(output), "--workers", str(args.workers),
                   "--worker-batch-size", str(args.worker_batch_size),
                   "--repeats", str(args.repeats), "--namespace", args.namespace]
        if args.smoke:
            command.append("--smoke")
        return subprocess.call(command, cwd=frozen, env=env)

    if not args.resume:
        code = invoke("prepare")
        if code:
            return code
    else:
        config = json.loads((output / "loadout-config.json").read_text(encoding="utf-8"))
        print(f"Existing frozen configuration: {len(config['cases'])} games; "
              f"namespace={config['namespace']}; smoke={config['smoke']}", flush=True)
    if args.summarize:
        code = invoke("summarize")
        if not code:
            package(output)
        return code
    if not args.run:
        print("Start/resume this snapshot:\npython " + str(Path(__file__).relative_to(root)) +
              ' --resume "' + str(output) + '" --run --workers ' + str(args.workers), flush=True)
        return 0
    code = 130
    try:
        code = invoke("run")
        return code
    finally:
        write_json(output / "run-status.json", dict(
            status="complete" if code == 0 else "failed_or_interrupted", exit_code=code))
        package(output)


if __name__ == "__main__":
    raise SystemExit(main())
