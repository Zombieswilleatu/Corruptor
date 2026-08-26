extends SceneTree


var failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed = load(
        "res://Prototype/UI2/PlayableUI2Showcase.tscn"
    )

    if packed == null:
        _fail("showcase_scene_load")
        _finish()
        return

    var screen = packed.instantiate()
    root.add_child(screen)

    await process_frame

    if (
        screen.controller == null
        or screen.controller.game == null
    ):
        _fail("showcase_game_created")
        _finish()
        return

    var game = screen.controller.game
    var human = screen.controller.get_human_player()

    if String(screen.showcase_invalid_reason).is_empty():
        _pass("showcase_stays_legal")
    else:
        _fail(
            "showcase_stays_legal_%s"
            % String(screen.showcase_invalid_reason)
        )

    if int(game.round) == 6:
        _pass("showcase_real_commitment_r6")
    else:
        _fail(
            "showcase_real_commitment_r%d"
            % int(game.round)
        )

    if (
        screen.controller.stage
        == screen.PlayableRoundControllerData.Stage.COMMITMENT
    ):
        _pass("showcase_stage_commitment")
    else:
        _fail("showcase_stage_commitment")

    if int(game.winner) < 0:
        _pass("showcase_nonterminal")
    else:
        _fail("showcase_nonterminal")

    if human != null and human.hand.size() > 0:
        _pass(
            "showcase_live_hand_%d"
            % human.hand.size()
        )
    else:
        _fail("showcase_live_hand")

    var bot_plan: Dictionary = screen.controller.get_bot_commitment()

    if bot_plan.is_empty():
        _fail("showcase_bot_commitment_prepared")
    else:
        _pass("showcase_bot_commitment_prepared")

    var obsolete_reflex_event: bool = false

    for event in screen.controller.events:
        if (
            int(event.get("round", -1)) == 6
            and String(event.get("phase", "")) == "reflex_bid"
        ):
            obsolete_reflex_event = true
            break

    if obsolete_reflex_event:
        _fail("showcase_omits_obsolete_reflex_bid")
    else:
        _pass("showcase_omits_obsolete_reflex_bid")

    var current_round_commit_event: bool = false

    for event in screen.controller.events:
        if (
            int(event.get("round", -1)) == 6
            and String(event.get("phase", "")) == "commitment"
        ):
            current_round_commit_event = true
            break

    if current_round_commit_event:
        _fail("showcase_stops_before_commitment_mutation")
    else:
        _pass("showcase_stops_before_commitment_mutation")

    _finish()


func _pass(name: String) -> void:
    print("PASS  %s" % name)


func _fail(name: String) -> void:
    failures += 1
    print("FAIL  %s" % name)


func _finish() -> void:
    print(
        "UI2 showcase failures: %d"
        % failures
    )
    quit(0 if failures == 0 else 1)
