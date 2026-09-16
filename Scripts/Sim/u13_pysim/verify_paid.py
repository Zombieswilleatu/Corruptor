"""Exact paid-development component and complete-game parity."""

from collections import Counter
from . import opening, paid_inputs as inputs, verify_full_match as full
from .copying import copy_data
from .verify import same

SCHEMA = "U13_PYSIM_PAID_DEVELOPMENT_STREAM_V1"


def components(take, specs):
    count, rejects, events = 0, 0, Counter()
    for spec in specs:
        cfg = spec["setup"]
        w = opening.world(cfg["seed"],cfg["lords"],cfg["castles"])
        loc = "paid_components["+spec["name"]+"]"
        same(dict(kind="paid_opening",name=spec["name"],setup=cfg,world=w),take("paid_opening"),loc+".opening")
        for i,entry in enumerate(spec["operations"]):
            before = copy_data(w)
            changed = inputs.component_apply(w,entry["operation"])
            same(before,w,loc+".input_immutable")
            result,w = changed["result"],changed["world"]
            same(entry["rejected"],result["action"]=="invalid",loc+f"[{i}].expected_rejection")
            if entry["rejected"]: same(before,w,loc+f"[{i}].rollback")
            same(dict(kind="paid_component",name=spec["name"],index=i,operation=entry["operation"],result=result,world=w),
                 take("paid_component"),loc+f"[{i}]")
            count += 1; rejects += int(entry["rejected"])
            events.update(r["event"]["type"] for r in result.get("events",[]))
    return dict(paid_component_cases=len(specs),paid_component_operations=count,paid_component_rejections=rejects,
                paid_component_event_coverage=dict(sorted(events.items())))


def options():
    manifest=inputs.load()
    same(inputs.SCHEMA,manifest["schema"],"input.schema")
    # Guard against hand-editing or accidentally pruning the directed corpus.
    same(inputs.components(),manifest["components"],"component_inputs")
    base=full.f.load()
    same(base["cases"],manifest["cases"][:len(base["cases"])] ,"ordinary_regression_inputs")
    same(4,len(manifest["cases"]),"complete_game_count")
    return dict(input_manifest=manifest,inputs_hash=inputs.input_hash(),stream_schema=SCHEMA,
                trailer=lambda take: components(take,manifest["components"]))


def verify(path,revision,source_hash,diagnostic=False,record_filter=None):
    report=full.verify(path,revision,source_hash,diagnostic,record_filter,**options())
    report["scope"]="four-Lord full games with paid Rites and Resummon; nine-Lord return components; declared powers and five full-match Lord integrations remain unsupported"
    report["input_policy"]=inputs.POLICY
    selected=Counter()
    for spec in inputs.load()["cases"][2:]:
        for op in spec["operations"]:
            if op["kind"]!="submit": continue
            for plan in op["plans"]:
                order=plan["order"]
                selected.update(order.get("rites",{}).keys())
                selected["summon"]+=int("summon" in order)
    report["paid_game_selected_components"]=dict(sorted(selected.items()))
    for kind in ("invocation","summon"):
        same(True,selected[kind]>0,"paid_input_coverage."+kind)
    for kind in ("LORD_RESUMMONED","PERSONAL_TEAR_CREATED"):
        same(True,report["event_coverage"].get(kind,0)>0,"paid_game_coverage."+kind)
    return report


def verify_rejections(path,revision,source_hash,diagnostic=False):
    count=full.verify_rejections(path,revision,source_hash,diagnostic,**options())
    # Collect only the separately labeled components, once; do not replay four
    # full matches for every late corruption of a component result.
    rows=[r for r in full.records(path) if r["kind"] in ("paid_opening","paid_component")]
    return count+component_rejections(rows,inputs.load()["components"])


def component_rejections(rows,specs):
    """Apply corruptions to an already collected independent component export."""
    probes=[
        ("['setup']",lambda r:r["kind"]=="paid_opening",lambda r:r["setup"].update(seed="wrong")),
        ("['index']",lambda r:r["kind"]=="paid_component",lambda r:r.update(index=999)),
        ("['operation']",lambda r:r["kind"]=="paid_component",lambda r:r["operation"].update(round=99)),
        ("['return_threat']",lambda r:"return_threat" in r.get("result",{}),lambda r:r["result"].update(return_threat=99)),
        ("['summon_round']",lambda r:r.get("operation",{}).get("kind")=="resolve_summon" and r["result"]["action"]=="resolved",
         lambda r:r["world"]["data"].update(summon_round=999)),
        ("['views']",lambda r:bool(r.get("result",{}).get("events")),lambda r:r["result"]["events"][0]["views"].__setitem__(0,None)),
        ("['used_ids']",lambda r:r.get("operation",{}).get("kind")=="resolve_rites" and r["result"]["action"]=="resolved",
         lambda r:r["world"]["entities"]["used_ids"].pop()),
    ]
    for marker,predicate,mutate in probes:
        changed=False;stream=iter(rows)
        def take(kind):
            nonlocal changed
            row=next(stream)
            if not changed and predicate(row):
                row=copy_data(row);mutate(row);changed=True
            return row
        try: components(take,specs)
        except ValueError as error:
            if not changed or marker not in str(error): raise ValueError(f"wrong paid rejection path {marker}: {error}") from error
        else: raise ValueError("corrupted paid component accepted: "+marker)
    return len(probes)
