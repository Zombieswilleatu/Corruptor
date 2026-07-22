"""Regression checks for Kanifous Penitent temporary-Guard cleanup."""

import corruptor_sim as sim


def test_defeated_penitent_guard_is_not_discarded_twice():
    game = sim.Game(
        ["Orias"],
        ["Kanifous"],
    )
    player = game.players[1]

    for participant in game.players:
        participant.action = "Ward"

    defeated_guard = sim.Card(
        "Vulture",
        4,
    )

    # Combat already discarded it, while the temporary-Guard tracker still
    # points at that same physical object until Resolution cleanup.
    game.discard = [defeated_guard]
    player.penitent_temp_guards = [defeated_guard]

    game._phase_resolution([0, 1])

    assert game.discard == [defeated_guard]
    assert game.discard[0] is defeated_guard
    assert player.penitent_temp_guards == []
