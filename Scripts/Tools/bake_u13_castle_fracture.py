#!/usr/bin/env python3
"""Bake bounded Castle shard settling using gravity and convex polygon contacts.

Standard library only. Run from any directory; --check verifies the committed
GDScript data without writing. The game performs no collision solves at runtime.
"""

import argparse
import math
from pathlib import Path

EXTENT = (1.0, 1.45)
DT = 1.0 / 30.0
ROWS = (
    ((0, 0), (0.51, 0), (1, 0)),
    ((0, 0.30), (0.40, 0.39), (1, 0.27)),
    ((0, 0.68), (0.61, 0.61), (1, 0.74)),
    ((0, 1), (0.46, 1), (1, 1)),
)
OUTPUT = Path(__file__).resolve().parents[2] / "Prototype/U13/U13CastleFracture.gd"


def add(a, b):
    return a[0] + b[0], a[1] + b[1]


def sub(a, b):
    return a[0] - b[0], a[1] - b[1]


def mul(a, scalar):
    return a[0] * scalar, a[1] * scalar


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def source():
    result = []
    for row in range(3):
        for col in range(2):
            a, b = ROWS[row][col:col + 2]
            d, c = ROWS[row + 1][col:col + 2]
            result.extend(((a, b, c), (a, c, d)))
    return result


def points(body):
    return [add(body["center"], p) for p in body["local"]]


def bounds(body):
    vertices = points(body)
    return (min(p[0] for p in vertices), min(p[1] for p in vertices),
            max(p[0] for p in vertices), max(p[1] for p in vertices))


def contain(body):
    x0, y0, x1, y1 = bounds(body)
    dx = -x0 if x0 < 0 else min(0, EXTENT[0] - x1)
    dy = -y0 if y0 < 0 else min(0, EXTENT[1] - y1)
    body["center"] = add(body["center"], (dx, dy))
    vx, vy = body["velocity"]
    body["velocity"] = (0 if dx else vx, 0 if dy else vy)


def separation(a, b):
    ax0, ay0, ax1, ay1 = bounds(a)
    bx0, by0, bx1, by1 = bounds(b)
    if ax1 <= bx0 or bx1 <= ax0 or ay1 <= by0 or by1 <= ay0:
        return (0, 0)
    pa, pb = points(a), points(b)
    minimum, normal = math.inf, (0, 0)
    for polygon in (pa, pb):
        for i, point in enumerate(polygon):
            edge = sub(polygon[(i + 1) % 3], point)
            axis = mul((-edge[1], edge[0]), 1 / math.hypot(*edge))
            aa, bb = [dot(p, axis) for p in pa], [dot(p, axis) for p in pb]
            if max(aa) <= min(bb) or max(bb) <= min(aa):
                return (0, 0)
            forward, backward = max(aa) - min(bb), max(bb) - min(aa)
            depth = min(forward, backward)
            if depth < minimum:
                minimum = depth
                normal = axis if forward <= backward else mul(axis, -1)
    return mul(normal, minimum)


def contacts(bodies):
    for body in bodies:
        contain(body)
    for a in range(len(bodies)):
        for b in range(a + 1, len(bodies)):
            delta = separation(bodies[a], bodies[b])
            if delta == (0, 0):
                continue
            bodies[a]["center"] = sub(bodies[a]["center"], mul(delta, 0.5))
            bodies[b]["center"] = add(bodies[b]["center"], mul(delta, 0.5))
            for index in (a, b):
                bodies[index]["velocity"] = mul(bodies[index]["velocity"], 0.55)
    for body in bodies:
        contain(body)


def bake(level):
    if level == 0:
        return source()
    severity = (level - 1) / 3.0
    bodies = []
    for index, uv in enumerate(source()):
        center = tuple(sum(p[axis] for p in uv) * EXTENT[axis] / 3 for axis in (0, 1))
        angle = (index % 5 - 2) * (0.008 + severity * 0.045)
        scale = 0.94 - severity * 0.16
        local = []
        for point in uv:
            x, y = sub((point[0], point[1] * EXTENT[1]), center)
            local.append(mul((x * math.cos(angle) - y * math.sin(angle),
                              x * math.sin(angle) + y * math.cos(angle)), scale))
        bodies.append(dict(anchor=center, center=center, velocity=(0, 0), local=local))
    # Weakened masonry retains support, but gravity closes spaces until an
    # actual shard polygon or the card container stops the piece.
    for _ in range(40):
        for body in bodies:
            dx, dy = sub(body["anchor"], body["center"])
            acceleration = (dx * 20, dy * (24 - severity * 20.5) + 0.65 + severity * 1.8)
            body["velocity"] = mul(add(body["velocity"], mul(acceleration, DT)), 0.78)
            body["center"] = add(body["center"], mul(body["velocity"], DT))
        for _ in range(3):
            contacts(bodies)
    # Static contact polish: no new energy, bounded work in this offline tool.
    for _ in range(96):
        contacts(bodies)
    validate(bodies)
    return [[(p[0], p[1] / EXTENT[1]) for p in points(body)] for body in bodies]


def validate(bodies):
    for body in bodies:
        for x, y in points(body):
            assert math.isfinite(x) and math.isfinite(y)
            assert -1e-8 <= x <= EXTENT[0] + 1e-8
            assert -1e-8 <= y <= EXTENT[1] + 1e-8
    for a in range(len(bodies)):
        for b in range(a + 1, len(bodies)):
            assert math.hypot(*separation(bodies[a], bodies[b])) < 1e-5, (a, b)


def validate_interpolation(poses):
    # Runtime linearly blends vertices between neighbouring contact poses.
    # Check all visible Integrity fractions, including rounded exported data.
    for level in range(1, 4):
        for step in range(21):
            blend = step / 20
            bodies = []
            for a, b in zip(poses[level], poses[level + 1]):
                vertices = []
                for p, q in zip(a, b):
                    p, q = tuple(round(v, 8) for v in p), tuple(round(v, 8) for v in q)
                    x = p[0] + (q[0] - p[0]) * blend
                    y = p[1] + (q[1] - p[1]) * blend
                    assert -1e-8 <= x <= 1 + 1e-8 and -1e-8 <= y <= 1 + 1e-8
                    vertices.append((x, y * EXTENT[1]))
                edge_a, edge_b = sub(vertices[1], vertices[0]), sub(vertices[2], vertices[0])
                assert edge_a[0] * edge_b[1] - edge_a[1] * edge_b[0] > 0
                bodies.append(dict(center=(0, 0), local=vertices))
            for a in range(len(bodies)):
                for b in range(a + 1, len(bodies)):
                    # Under 0.08px at 300px enlarged preview width. Exact contact
                    # endpoints are tested more strictly in validate().
                    assert math.hypot(*separation(bodies[a], bodies[b])) < 0.00025


def emit(poses):
    lines = ["extends RefCounted", "", "# Generated by Scripts/Tools/bake_u13_castle_fracture.py.",
             "# Gravity + polygon contacts + a four-wall container, baked offline.",
             "# Runtime only interpolates these shared shapes. Consumers must not mutate.",
             "static var _poses: Array = ["]
    for pose in poses:
        lines.append("\t[")
        for triangle in pose:
            vertices = ", ".join("Vector2(%.8f, %.8f)" % p for p in triangle)
            lines.append("\t\tPackedVector2Array([" + vertices + "]),")
        lines.append("\t],")
    lines.extend(["]", "", "", "static func source() -> Array:", "\treturn _poses[0]", "", "",
                  "static func pose(level: int) -> Array:", "\treturn _poses[clampi(level, 0, 4)]", ""])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    poses = [bake(level) for level in range(5)]
    # More damage must create visibly more open space and lower the artwork.
    centers = [sum(p[1] for tri in pose for p in tri) / 36 for pose in poses]
    assert all(a < b for a, b in zip(centers, centers[1:])), centers
    validate_interpolation(poses)
    text = emit(poses)
    if args.check:
        assert OUTPUT.read_text() == text, "Baked data differs; regenerate and review."
    else:
        OUTPUT.write_text(text)
    print("Castle bake: 12 shards, 4 damage poses; bounds, contacts, settling and data checks passed.")


if __name__ == "__main__":
    main()
