"""Stream exact full-state parity without feeding reference state to rules."""

from collections import Counter
import hashlib
from pathlib import Path

from . import codec, economy as e, full_match_inputs as f
from .full_match import FullMatch, VERSION
from .marching_game import LORDS
from . import settlement_inputs
from .lifecycle import RoundRules, settle
from . import marching_game
from .copying import copy_data
from .verify import same, shape, trace_identity

SCHEMA = "U13_PYSIM_FULL_MATCH_STREAM_V1"
TRANSPORT = "full state except append-only event prefix; all semantic rows and views retained"


def records(path):
    with Path(path).open(encoding="utf-8") as source:
        for number,line in enumerate(source,1):
            try:
                yield codec.loads(line)
            except (ValueError,TypeError) as error:
                raise ValueError(f"stream line {number}: {error}") from error


def verify(path, revision, source_hash, diagnostic=False, record_filter=None, *,
           input_manifest=None, inputs_hash=None, stream_schema=SCHEMA, trailer=None):
    stream = iter(records(path))
    def take(kind):
        try: row = next(stream)
        except StopIteration: raise ValueError("stream truncated before "+kind) from None
        if record_filter: row = record_filter(row)
        same(kind,row.get("kind"),"stream.kind")
        return row
    header = take("header")
    shape(header,{"kind","schema","identity","inputs_sha256","event_transport","scope_lords"},"header")
    same(stream_schema,header["schema"],"schema")
    expected_hash = f.input_hash() if inputs_hash is None else inputs_hash
    same(expected_hash,header["inputs_sha256"],"inputs_sha256")
    same(TRANSPORT,header["event_transport"],"event_transport")
    same(list(LORDS),header["scope_lords"],"scope_lords")
    manifest = f.load() if input_manifest is None else input_manifest
    if input_manifest is None:
        same(f.SCHEMA,manifest["schema"],"input.schema")
    games, total_counts, tick_probes, tick_frames = [],Counter(),0,0
    for spec in manifest["cases"]:
        path_name = "games["+spec["name"]+"]"
        opening = take("opening")
        shape(opening,{"kind","name","setup","state"},path_name+".opening")
        same(spec["name"],opening["name"],path_name+".name")
        same(spec["setup"],opening["setup"],path_name+".setup")
        trace_identity(dict(identity=header["identity"],setup=opening["setup"],opening=opening["state"],records=[]),
                       revision,source_hash,diagnostic,path_name)
        match = FullMatch(spec["setup"])
        same(match.snapshot(),opening["state"],path_name+".opening.state")
        prefix,history,counts,orders,peaks = 0,[],Counter(),Counter(),0
        operations = spec["operations"]+[dict(kind="next_round"),dict(kind="step",hook="")]
        for index,op in enumerate(operations):
            loc = path_name+f".operations[{index}].round={match.clock.round}.hook={match.clock.hook}"
            if index in spec["marching_probes"]:
                probe = take("marching_probe")
                # Internal observation is copied; do not expose live match state.
                ctx = dict(world=copy_data(match._state["world"]),round=match.clock.round,seed=match._state["seed"],
                           hook=match.clock.hook,player_order=match._state["player_order"][:],persistent_effects=[])
                result = marching_game.resolve(ctx,RoundRules.march_reaction,capture_ticks=True)
                same(True,result["action"] == "resolved",loc+".tick_probe.resolved")
                ticks = [r for r in result["events"] if r["event"]["type"] == "MARCHING_TICK"]
                same(200,len(ticks),loc+".tick_probe.count")
                for ordinal,(actual,expected) in enumerate(zip(result["events"],probe["result"]["events"])):
                    same(actual,expected,loc+f".tick_probe.events[{ordinal}].tick="+str(actual["event"]["data"].get("tick","?")))
                same(dict(kind="marching_probe",name=spec["name"],index=index,context=ctx,result=result),probe,loc+".tick_probe")
                tick_probes += 1;tick_frames += len(ticks)
            row = take("transition")
            shape(row,{"kind","name","index","operation","result","state","event_prefix","events","outcome"},loc)
            same(spec["name"],row["name"],loc+".name")
            same(index,row["index"],loc+".index")
            same(op,row["operation"],loc+".input")
            result = match.apply(op)
            same(result,row["result"],loc+".result")
            terminal_probe = index >= len(spec["operations"])
            same(terminal_probe,result["action"] == "invalid",loc+".expected_rejection")
            state = match.snapshot()
            events = state.pop("events")
            same(prefix,row["event_prefix"],loc+".event_prefix")
            same(history,events["rows"][:prefix],loc+".immutable_history")
            appended = dict(events,rows=events["rows"][prefix:])
            shape(row["events"],events.keys(),loc+".events")
            same(len(appended["rows"]),len(row["events"]["rows"]),loc+".events.count")
            for ordinal,(actual,expected) in enumerate(zip(appended["rows"],row["events"]["rows"])):
                data = actual["event"]["data"]
                event_path = loc+f".events[{ordinal}].tick={data.get('tick','?')}."+actual["event"]["type"]
                same(actual,expected,event_path)
            same(appended,row["events"],loc+".events")
            same(state,row["state"],loc+".state")
            same(match.outcome(),row["outcome"],loc+".outcome")
            same(True,e.cards_valid(match._state["world"]),loc+".card_conservation")
            same(True,match.clock.round <= manifest["round_cap"],loc+".round_cap")
            if not terminal_probe and index < len(spec["operations"])-1:
                same(-1,match.outcome()["winner"],loc+".premature_finish")
            counts.update(r["event"]["type"] for r in appended["rows"])
            peaks = max(peaks,sum(r["kind"] == "marcher" for r in state["world"]["entities"]["entities"]))
            if op["kind"] == "submit": orders.update(p["order"].get("action","Pass") for p in op["plans"])
            prefix,history = len(events["rows"]),events["rows"]
        last = take("finished")
        same(dict(kind="finished",name=spec["name"],operations=len(spec["operations"]),outcome=match.outcome(),event_rows=prefix),last,path_name+".finished")
        same(True,match.clock.completed and match.outcome()["winner"] != -1,path_name+".terminal")
        same(match.clock.round*2,counts["VACANT_THRONE_RESOLVED"],path_name+".round_settlement")
        same(1,counts["MATCH_FINISHED"],path_name+".single_victory")
        digest = hashlib.sha256(codec.dumps(match.snapshot()).encode()).hexdigest()
        games.append(dict(name=spec["name"],setup=spec["setup"],operations_matched=len(spec["operations"]),
            terminal_rejections_matched=2,rounds=match.clock.round,outcome=match.outcome(),
            final_state_sha256=digest,event_rows=prefix,peak_marchers=peaks,orders=dict(sorted(orders.items())),
            event_coverage=dict(sorted(counts.items()))))
        total_counts.update(counts)
    same(settlement_inputs.cases(),manifest["settlements"],"settlement_inputs")
    for spec in manifest["settlements"]:
        row = take("settlement")
        world = settlement_inputs.initial(manifest["cases"][0]["setup"],spec)
        initial = copy_data(world)
        events = settle(world,spec["round"])
        same(dict(kind="settlement",name=spec["name"],initial=initial,world=world,events=events),row,"settlements["+spec["name"]+"]")
    extra = trailer(take) if trailer is not None else {}
    try: next(stream)
    except StopIteration: pass
    else: raise ValueError("stream has extra records")
    for kind in ("MARCHER_CONTACT","MARCHER_CLASH","MARCHER_DEFEATED","MARCHER_RANGED_ATTACK",
                 "MARCHER_REGENERATED","GUARD_PAIR_FORMED","WORK_RESOLVED","CASTLE_ACTIVATED",
                 "LORD_BANISHED","VACANT_THRONE_RESOLVED","MATCH_FINISHED"):
        same(True,total_counts[kind] > 0,"coverage."+kind)
    return dict(python_mirror=VERSION,source_revision=revision,source_sha256=source_hash,inputs_sha256=expected_hash,
        runtime=header["identity"]["runtime"],reference_platform=header["identity"]["platform"],diagnostic_only=diagnostic,
        complete_games_matched=len(games),complete_rounds_matched=sum(g["rounds"] for g in games),
        game_operations_matched=sum(g["operations_matched"] for g in games),fixture_operations=0,
        terminal_rejections_matched=2*len(games),scope_lords=list(LORDS),
        directed_settlement_components_matched=len(manifest["settlements"]),
        scope="explicit ordinary decisions; no declared powers, paid Rites or Resummon; not roster-complete parity",
        event_profile="U13_BATCH_EVENTS_V1",full_world_tick_probes_matched=tick_probes,tick_frames_compared=tick_frames,
        all_semantic_rows_and_views_matched=True,
        games=games,event_coverage=dict(sorted(total_counts.items())),failures=0,**extra)


def verify_rejections(path, revision, source_hash, diagnostic=False, **options):
    """Early corruptions keep this gate bounded while exercising real replay."""
    probes = [
        ("source_revision", lambda r:r["kind"] == "header", lambda r:r["identity"].update(source_revision="wrong")),
        ("source_sha256", lambda r:r["kind"] == "header", lambda r:r["identity"].update(source_sha256="wrong")),
        ("inputs_sha256", lambda r:r["kind"] == "header", lambda r:r.update(inputs_sha256="wrong")),
        ("event_transport", lambda r:r["kind"] == "header", lambda r:r.update(event_transport="dropped fields")),
        ("scope_lords", lambda r:r["kind"] == "header", lambda r:r["scope_lords"].append("Kroni")),
        ("opening.state", lambda r:r["kind"] == "opening", lambda r:r["state"]["world"]["entities"]["used_ids"].pop()),
        (".input", lambda r:r["kind"] == "transition", lambda r:r["operation"].update(fixture_patch=True)),
        (".index", lambda r:r["kind"] == "transition", lambda r:r.update(index=99)),
        ("event_prefix", lambda r:r["kind"] == "transition", lambda r:r.update(event_prefix=1)),
        (".state", lambda r:r["kind"] == "transition", lambda r:r["state"]["runtime"].update(next_hook_index=9)),
        (".events", lambda r:r["kind"] == "transition" and r["index"] == 2, lambda r:r["events"]["rows"].pop()),
        ("views", lambda r:r["kind"] == "transition" and r["index"] == 2,
         lambda r:r["events"]["rows"][0]["views"].reverse()),
        (".outcome", lambda r:r["kind"] == "transition", lambda r:r["outcome"].update(winner=0)),
    ]
    for marker,predicate,mutate in probes:
        changed = False
        def corrupt(row):
            nonlocal changed
            if not changed and predicate(row):
                mutate(row); changed = True
            return row
        try: verify(path,revision,source_hash,diagnostic,corrupt,**options)
        except ValueError as error:
            if not changed or marker not in str(error):
                raise ValueError(f"Wrong first-divergence path for {marker}: {error}") from error
        else: raise ValueError("Corrupted full-match evidence accepted: "+marker)
    return len(probes)
