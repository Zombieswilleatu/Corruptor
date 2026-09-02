#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import shutil
import subprocess
import sys
from pathlib import Path

MARKER = "UI2_CONSTRUCTION_BLUEPRINT_VESSEL_LORE_V1"

NEW_SHADER = r'''shader_type canvas_item;
render_mode unshaded;

// UI2_CASTLE_CONSTRUCTION_REVEAL_V1
// CASTLE_CONSTRUCTION_SHADER_GODOT42_HOTFIX_V3
// CASTLE_CONSTRUCTION_SHADER_GODOT42_HOTFIX_V4
// UI2_CONSTRUCTION_BLUEPRINT_VESSEL_LORE_V1
//
// Built portion: original Castle artwork.
// Unbuilt portion: opaque dark architectural ghost with gold etched detail.
// Construction grows upward from the bottom of the illustration.
uniform float build_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float art_top : hint_range(0.0, 1.0) = 0.17;
uniform float art_bottom : hint_range(0.0, 1.0) = 0.625;
uniform vec4 outline_color : source_color = vec4(0.78, 0.61, 0.23, 1.0);
uniform float frontier_width : hint_range(0.001, 0.05) = 0.010;


float _luma(vec3 color_value) {
	return dot(
		color_value,
		vec3(0.299, 0.587, 0.114)
	);
}


float _draft_hatch(vec2 uv) {
	float diagonal_a = smoothstep(
		0.92,
		1.0,
		fract(
			(uv.x + uv.y)
			* 54.0
		)
	);

	float diagonal_b = smoothstep(
		0.95,
		1.0,
		fract(
			(uv.x - uv.y + 1.0)
			* 71.0
		)
	);

	return max(
		diagonal_a,
		diagonal_b
	);
}


void fragment() {
	vec4 source_pixel = COLOR;
	vec4 result = source_pixel;

	float safe_height = max(
		0.0001,
		art_bottom - art_top
	);

	if (
		build_ratio < 0.999
		&& UV.y >= art_top
		&& UV.y <= art_bottom
	) {
		float local_y = (
			(UV.y - art_top)
			/ safe_height
		);

		float unbuilt_end = (
			1.0 - build_ratio
		);

		if (
			local_y < unbuilt_end
		) {
			float source_luma = _luma(
				source_pixel.rgb
			);

			float broad_detail = smoothstep(
				0.045,
				0.34,
				source_luma
			);

			float fine_detail = smoothstep(
				0.20,
				0.66,
				source_luma
			);

			float hatch = (
				_draft_hatch(UV)
				* 0.075
			);

			vec3 dark_ghost = (
				source_pixel.rgb
				* 0.12
			);

			vec3 etched_gold = (
				outline_color.rgb
				* (
					broad_detail * 0.34
					+ fine_detail * 0.54
					+ hatch
				)
			);

			result.rgb = (
				vec3(0.010, 0.009, 0.008)
				+ dark_ghost
				+ etched_gold
			);

			result.a = source_pixel.a;
		}

		float frontier = (
			1.0
			- smoothstep(
				0.0,
				frontier_width,
				abs(
					local_y
					- unbuilt_end
				)
			)
		);

		if (
			build_ratio > 0.001
			&& build_ratio < 0.999
		) {
			result.rgb = mix(
				result.rgb,
				vec3(0.92, 0.72, 0.28),
				frontier * 0.92
			);

			float glow = (
				1.0
				- smoothstep(
					0.0,
					frontier_width * 3.2,
					abs(
						local_y
						- unbuilt_end
					)
				)
			);

			result.rgb += (
				outline_color.rgb
				* glow
				* 0.10
			);
		}
	}

	COLOR = result;
}
'''


def fail(message: str) -> None:
    print(f"\nERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        fail(
            f"{label}: expected anchor exactly once, "
            f"found {count}. NOTHING WRITTEN."
        )
    return text.replace(old, new, 1)


def main() -> int:
    root = Path.cwd().resolve()

    shader_path = (
        root / "Prototype" / "UI2" / "Shaders"
        / "CastleConstructionProgress.gdshader"
    )
    action_path = root / "Prototype" / "UI2" / "ActionZone.gd"

    for path in (shader_path, action_path):
        if not path.is_file():
            fail(
                "Run from the Corruptor repo root; missing "
                + str(path.relative_to(root))
            )

    shader = shader_path.read_text(encoding="utf-8")
    action = action_path.read_text(encoding="utf-8")

    if MARKER in shader:
        print(
            "UI2 CONSTRUCTION BLUEPRINT / VESSEL LORE V1 "
            "ALREADY INSTALLED"
        )
        return 0

    if "CASTLE_CONSTRUCTION_SHADER_GODOT42_HOTFIX_V4" not in shader:
        fail(
            "Expected the successfully compiling V4 construction shader. "
            "NOTHING WRITTEN."
        )

    exact_vessel_choice = '"OFFER LORD · +1 Tear · opponent +1 Soul"'
    if exact_vessel_choice not in action:
        fail(
            "Expected the previous Vessel UI polish patch first. "
            "NOTHING WRITTEN."
        )

    old_vessel = r'''        "RESOLUTION_VESSEL":
            title_label.text = "THE VESSEL"
            phase_label.text = "ONCE PER MATCH · LIVING LORD REQUIRED"
            phase_panel.text = (
                "Offer your living Lord to gain 1 Tear. Your opponent gains "
                + "1 Soul and all of your Lord Guards are discarded. The Lord "
                + "leaves play as OFFERED AS VESSEL — it does not enter the "
                + "Breach. If summoned later, that Lord returns at Threat 2. "
                + "The Tear is gained immediately and can complete Dominion."
            )
            _show_primary("Choose your fate:")
'''

    new_vessel = r'''        "RESOLUTION_VESSEL":
            title_label.text = "THE VESSEL"
            phase_label.text = "ONCE PER MATCH · AFTER YOUR ACTION"
            phase_panel.text = (
                "The Veil does not open for the dead. It opens for what is "
                + "willingly surrendered. You may offer your living Lord as "
                + "the Vessel — abandoning the ruler of your domain for one "
                + "final pull upon the abyss.\n\n"
                + "Offering the Vessel immediately grants you 1 Tear, while "
                + "your opponent gains 1 Soul. Every Lord Guard is destroyed "
                + "and your Lord leaves play as OFFERED AS VESSEL rather than "
                + "entering the Breach. If that Lord is summoned again later, "
                + "it returns at Threat 2. Because the Tear is gained at once, "
                + "this sacrifice can complete Dominion immediately."
            )
            _show_primary("Choose your fate:")
'''

    action = replace_once(
        action,
        old_vessel,
        new_vessel,
        "Vessel main lore/explanation block",
    )

    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = (
        root / ".corruptor_backups"
        / f"{stamp}_ui2_construction_blueprint_vessel_lore_v1"
    )

    for path in (shader_path, action_path):
        dst = backup / path.relative_to(root)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)

    try:
        shader_path.write_text(
            NEW_SHADER,
            encoding="utf-8",
            newline="\n",
        )
        action_path.write_text(
            action,
            encoding="utf-8",
            newline="\n",
        )

        shader_check = shader_path.read_text(encoding="utf-8")
        action_check = action_path.read_text(encoding="utf-8")

        if MARKER not in shader_check:
            raise RuntimeError("construction blueprint marker missing")

        if "result.a = source_pixel.a;" not in shader_check:
            raise RuntimeError("unfinished Castle is not opaque")

        if "_draft_hatch" not in shader_check:
            raise RuntimeError("architectural hatch treatment missing")

        for pattern in (
            "TEXTURE_PIXEL_SIZE",
            "texture(TEXTURE",
            "if local_y",
        ):
            if pattern in shader_check:
                raise RuntimeError(
                    "problematic shader construct survived: " + pattern
                )

        if "The Veil does not open for the dead." not in action_check:
            raise RuntimeError("Vessel lore block missing")

        if exact_vessel_choice not in action_check:
            raise RuntimeError("concise Vessel choice labels were lost")

        proc = subprocess.run(
            ["git", "diff", "--check"],
            cwd=root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                proc.stdout.strip() or "git diff --check failed"
            )

    except Exception as exc:
        for path in (shader_path, action_path):
            src = backup / path.relative_to(root)
            shutil.copy2(src, path)
        fail(
            "Validation failed; both files restored. "
            + str(exc)
        )

    print(
        "\nUI2 CONSTRUCTION BLUEPRINT / VESSEL LORE V1 INSTALLED"
    )
    print(f"Backup: {backup}")

    print("\nConstruction:")
    print("  - unfinished fraction is opaque, not transparent gray")
    print("  - unfinished Castle keeps a dark skeletal silhouette")
    print("  - engraved source detail is recolored as architectural gold")
    print("  - subtle diagonal drafting marks reinforce the blueprint look")
    print("  - exact progress/14 bottom-up reveal remains unchanged")
    print("  - construction frontier is thinner, brighter, and cleaner")

    print("\nVessel:")
    print("  - main body now has a lore paragraph before the mechanics")
    print("  - full consequences are still stated explicitly")
    print("  - short KEEP LORD / OFFER LORD choices remain unchanged")

    print(
        "\nNo mechanics, costs, AI, balance, or Resolution logic changed."
    )
    print("Nothing staged or committed.")
    print("Validation: git diff --check PASS")
    print(
        "\nNEXT: relaunch UI2 and inspect a Castle around 4-7/14, "
        "then reach Vessel once to judge the prose density."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
