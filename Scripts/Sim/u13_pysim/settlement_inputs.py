"""Directed end-of-round components, separate from the fixture-free games."""

from . import economy as e, opening


def cases():
    base = dict(round=13,souls=[0,0],personal_tears=[0,0],neutral_tears=0,
                alive=[True,True],present=[True,True],prior_counts=[0,0])
    return [dict(base,name=name,**changes) for name,changes in (
        ("ritual_precedes_collapse_and_ties",dict(souls=[12,13],neutral_tears=30)),
        ("absent_lord_cannot_ritual",dict(souls=[15,2],neutral_tears=25,alive=[False,False],present=[False,False],prior_counts=[2,2])),
        ("collapse_soul_tie_player_zero",dict(round=21,souls=[8,8],neutral_tears=24)),
        ("pressure_enables_dominion",dict(personal_tears=[5,4],neutral_tears=2)),
        ("equal_personal_tears_no_dominion",dict(personal_tears=[5,5],neutral_tears=2)),
        ("throne_reward_enables_ritual",dict(souls=[11,0],alive=[True,False],present=[True,False],prior_counts=[0,2])),
        ("banishment_round_counts_as_present",dict(round=12,alive=[False,True],present=[True,True],prior_counts=[2,0])),
        ("throne_second_absent_round_is_grace",dict(round=12,alive=[False,True],present=[False,True],prior_counts=[1,0])),
    )]


def initial(setup,spec):
    world = opening.world(setup["seed"],setup["lords"],setup["castles"])
    n,d = spec["round"],world["data"]
    for pid in (0,1):
        world["players"][pid]["resources"].update(souls=spec["souls"][pid],personal_tears=spec["personal_tears"][pid])
        e.entity(world,world["players"][pid]["lord_entity_id"])["attributes"]["alive"] = spec["alive"][pid]
    d["neutral_tears"] = spec["neutral_tears"]
    d["vacant_throne"].update(round=n,completed_round=n-1,counts=spec["prior_counts"][:],
                            prior_counts=spec["prior_counts"][:],present=spec["present"][:])
    d["victory"]["checked_round"] = n-1
    return world
