#!/usr/bin/env python3
"""Paint the icons of building pieces straight from their looks (Kathleen, 10 Nov 2026; buildables B1 to B6 and item system C2 to C4).

Each icon is the piece's own look from src/client/piece_look.gd (run in Python by tools/look_runtime.py, the same boxes, cylinders and domes
at the same sizes), drawn to the painted icons' rig (tools/paint_structure_icons.py render: the warm key light from the top left, the soft fill
and gold rim, flat-shaded facets, 128 x 128 with the piece filling about 80 %). So a piece's icon always matches what is built, and a new look
gets its icon by adding one row here.

A row is item: (look, view); the look is a look_table name, or a function that builds a node (a carried lantern is the hanging one's body). The view is the turn of the piece before the rig's three-quarter camera: walls, doorways and fences square on with
a little turn, floors and plots tipped up a little, roofs from the side, stations and furniture from the front left like the painted stations.

    python3 tools/paint_look_icons.py [--out assets/ui/item_icons] [--only id,id] [--sheet sheet.png]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look_runtime   # noqa: E402
from paint_basic_icons import lift_dark, rot_x, rot_y   # noqa: E402
from paint_structure_icons import FURNITURE_VIEW, SLAB_VIEW, STATION_VIEW, WALL_VIEW, flame, render   # noqa: E402
from PIL import Image   # noqa: E402

FENCE_VIEW = rot_y(math.radians(24.0))
STAIR_VIEW = rot_y(math.radians(-50.0))
PLOT_VIEW = rot_y(math.radians(-20.0)) @ rot_x(math.radians(14.0))
WALL_HUNG = rot_y(math.radians(-30.0))
CORNER_VIEW = rot_y(math.radians(-45.0))

# item: (look, view). Doorways show their open look (the gap reads at slot size; a shut door reads as a wall), gates their shut one.
ITEMS = {
    # B1a: foundations, doorways, windows
    "log_foundation": ("log_foundation", SLAB_VIEW), "brick_foundation": ("brick_foundation", SLAB_VIEW),
    "log_doorway": ("log_doorway_open", WALL_VIEW), "stone_doorway": ("stone_doorway_open", WALL_VIEW), "brick_doorway": ("brick_doorway_open", WALL_VIEW),
    "thatch_window": ("thatch_window", WALL_VIEW), "log_window": ("log_window", WALL_VIEW), "stone_window": ("stone_window", WALL_VIEW),
    "brick_window": ("brick_window", WALL_VIEW),
    # B2: fences and gates
    "thatch_fence": ("thatch_fence", FENCE_VIEW), "thatch_gate": ("thatch_gate", FENCE_VIEW), "wood_fence": ("wood_fence", FENCE_VIEW),
    "wood_gate": ("wood_gate", FENCE_VIEW), "log_fence": ("log_fence", FENCE_VIEW), "log_gate": ("log_gate", FENCE_VIEW),
    "log_palisade": ("log_palisade", FENCE_VIEW), "log_palisade_gate": ("log_palisade_gate", FENCE_VIEW), "stone_fence": ("stone_fence", FENCE_VIEW),
    "stone_gate": ("stone_gate", FENCE_VIEW), "brick_fence": ("brick_fence", FENCE_VIEW), "brick_gate": ("brick_gate", FENCE_VIEW),
    "iron_fence": ("iron_fence", FENCE_VIEW), "iron_gate": ("iron_gate", FENCE_VIEW),
    # B1c: pillars and roof corners
    "thatch_pillar": ("thatch_pillar", STATION_VIEW), "wooden_pillar": ("wooden_pillar", STATION_VIEW), "log_pillar": ("log_pillar", STATION_VIEW),
    "stone_pillar": ("stone_pillar", STATION_VIEW), "brick_pillar": ("brick_pillar", STATION_VIEW),
    "thatch_roof_corner": ("thatch_roof_corner", CORNER_VIEW), "wooden_roof_corner": ("wooden_roof_corner", CORNER_VIEW),
    "log_roof_corner": ("log_roof_corner", CORNER_VIEW), "stone_roof_corner": ("stone_roof_corner", CORNER_VIEW),
    "brick_roof_corner": ("brick_roof_corner", CORNER_VIEW),
    # B3: furniture and storage
    "log_bench": ("log_bench", FURNITURE_VIEW), "log_table": ("log_table", FURNITURE_VIEW), "stone_bench": ("stone_bench", FURNITURE_VIEW),
    "stone_table": ("stone_table", FURNITURE_VIEW), "iron_bench": ("iron_bench", FURNITURE_VIEW), "iron_chair": ("iron_chair", rot_y(math.radians(-40.0))),
    "iron_table": ("iron_table", FURNITURE_VIEW), "stone_workbench": ("stone_workbench", STATION_VIEW), "wooden_shelf": ("wooden_shelf", STATION_VIEW),
    "wooden_cupboard": ("wooden_cupboard", STATION_VIEW), "wooden_barrel": ("wooden_barrel", STATION_VIEW),
    # B1b: stairs, railings, the double and metal doorways
    "log_stairs": ("log_stairs", STAIR_VIEW), "stone_stairs": ("stone_stairs", STAIR_VIEW), "brick_stairs": ("brick_stairs", STAIR_VIEW),
    "wooden_railing": ("wooden_railing", FENCE_VIEW), "iron_railing": ("iron_railing", FENCE_VIEW),
    "double_doorway": ("double_doorway_open", WALL_VIEW), "iron_doorway": ("iron_doorway_open", WALL_VIEW), "steel_doorway": ("steel_doorway_open", WALL_VIEW),
    # B4: lights
    "wooden_hanging_lantern": ("wooden_hanging_lantern", STATION_VIEW), "iron_hanging_lantern": ("iron_hanging_lantern", STATION_VIEW),
    "iron_wall_lantern": ("iron_wall_lantern", WALL_HUNG), "wooden_torch_post": ("wooden_torch_post", STATION_VIEW),
    "stone_torch_pillar": ("stone_torch_pillar", STATION_VIEW), "iron_torch_stand": ("iron_torch_stand", STATION_VIEW),
    "wooden_lamp_post": ("wooden_lamp_post", STATION_VIEW), "iron_lamp_post": ("iron_lamp_post", STATION_VIEW),
    "stone_lamp_post": ("stone_lamp_post", STATION_VIEW), "stone_brazier": ("stone_brazier", STATION_VIEW), "iron_brazier": ("iron_brazier", STATION_VIEW),
    # B5: garden
    "thatch_garden_plot": ("thatch_garden_plot", PLOT_VIEW), "wooden_garden_plot": ("wooden_garden_plot", PLOT_VIEW),
    "stone_garden_plot": ("stone_garden_plot", PLOT_VIEW), "brick_garden_plot": ("brick_garden_plot", PLOT_VIEW),
    "wooden_planter_box": ("wooden_planter_box", STATION_VIEW), "stone_planter": ("stone_planter", STATION_VIEW),
    "wooden_trellis": ("wooden_trellis", STATION_VIEW), "wooden_compost_bin": ("wooden_compost_bin", STATION_VIEW),
    "thatch_scarecrow": ("thatch_scarecrow", STATION_VIEW), "wooden_cold_frame": ("wooden_cold_frame", STATION_VIEW),
    # B6: water
    "stone_well": ("stone_well", STATION_VIEW), "wooden_hand_pump": ("wooden_hand_pump", STATION_VIEW), "iron_hand_pump": ("iron_hand_pump", STATION_VIEW),
    "log_trough": ("log_trough", STATION_VIEW), "wooden_trough": ("wooden_trough", STATION_VIEW), "stone_trough": ("stone_trough", STATION_VIEW),
    "wooden_channel": ("wooden_channel", STATION_VIEW), "wooden_channel_corner": ("wooden_channel_corner", STATION_VIEW),
    "wooden_channel_tee": ("wooden_channel_tee", STATION_VIEW), "wooden_sluice": ("wooden_sluice", STATION_VIEW),
    "stone_channel": ("stone_channel", STATION_VIEW), "stone_channel_corner": ("stone_channel_corner", STATION_VIEW),
    "stone_channel_tee": ("stone_channel_tee", STATION_VIEW), "clay_pipe_run": ("clay_pipe_run", STATION_VIEW),
    "clay_pipe_elbow": ("clay_pipe_elbow", STATION_VIEW), "clay_pipe_tee": ("clay_pipe_tee", STATION_VIEW), "iron_pipe": ("iron_pipe", STATION_VIEW),
    "iron_pipe_elbow": ("iron_pipe_elbow", STATION_VIEW), "iron_tap": ("iron_tap", STATION_VIEW), "iron_deep_well_pump": ("iron_deep_well_pump", STATION_VIEW),
    "stone_cistern": ("stone_cistern", STATION_VIEW), "stone_raised_cistern": ("stone_raised_cistern", STATION_VIEW),
    # Item system C2: stations
    "kiln": ("kiln", STATION_VIEW), "tanning_rack": ("tanning_rack", STATION_VIEW), "drying_rack": ("drying_rack", STATION_VIEW),
    "smoker": ("smoker", STATION_VIEW), "oil_press": ("oil_press", STATION_VIEW),
    # Item system C3 and C4: stores, racks, wall pieces, stations
    "storage_jar": ("storage_jar", STATION_VIEW), "hide_sack": ("hide_sack", STATION_VIEW), "wicker_basket": ("wicker_basket", STATION_VIEW),
    "weapon_rack": ("weapon_rack", STATION_VIEW), "armour_stand": ("armour_stand", STATION_VIEW), "sign": ("sign", STATION_VIEW),
    "tusk_mount": ("tusk_mount", WALL_HUNG), "clay_bloomery": ("clay_bloomery", STATION_VIEW), "stonecutters_bench": ("stonecutters_bench", STATION_VIEW),
}


def carried_lantern(iron):
    """Wooden or Iron - Lantern (carried, B4): the hanging lantern's own body (piece_look _lantern) with a bail handle over it instead of a chain."""
    look_runtime.looks()
    rt = look_runtime
    root = rt.Node3D()
    rt._space["_lantern"](root, rt.Vector3(), iron)
    frame = rt._iron if iron else rt._frame
    bail = [rt.Vector3(-0.1, 0.2, 0.0), rt.Vector3(-0.09, 0.36, 0.0), rt.Vector3(0.0, 0.42, 0.0), rt.Vector3(0.09, 0.36, 0.0), rt.Vector3(0.1, 0.2, 0.0)]

    for k in range(len(bail) - 1):
        rt._rod(root, bail[k], bail[k + 1], 0.018, frame)

    return root


def fish_trap_kit():
    """Fish trap (the carried kit, #941): the trap's own cone, carried as it is made, without the stakes it is set with."""
    rt = look_runtime
    root = rt.build("fish_trap_set")
    cone = root.children[0]
    root.children = [cone]
    cone.position = rt.Vector3(0.0, 0.2, 0.0)
    cone.rotation = rt.Vector3(0.0, 0.0, 0.0)
    return root


def bird_trap_kit():
    """Bird trap (the carried kit, #941): the cage's sticks bundled flat in two layers, tied twice with twine, the trigger's three sticks on top."""
    rt = look_runtime
    rt.looks()
    root = rt.Node3D()
    twine = rt._tone_mat(rt.Color(0.7, 0.58, 0.36))

    for k in range(7):
        rt._box(root, rt.Vector3(0.56 - 0.03 * (k % 3), 0.04, 0.04), rt.Vector3(0.0, 0.02 + 0.04 * (k // 4), -0.12 + 0.04 * (k % 4) + 0.02 * (k // 4)), rt._log)

    for x in (-0.16, 0.16):
        rt._box(root, rt.Vector3(0.03, 0.1, 0.19), rt.Vector3(x, 0.04, -0.04), twine)

    for k, (a, b) in enumerate((((-0.2, 0.1, -0.08), (0.18, 0.1, 0.02)), ((-0.12, 0.11, 0.04), (0.14, 0.11, -0.1)), ((-0.04, 0.12, -0.12), (0.06, 0.12, 0.08)))):
        rt._rod(root, rt.Vector3(*a), rt.Vector3(*b), 0.025, rt._frame)

    return root


ITEMS["fish_trap_set"] = ("fish_trap_set", STATION_VIEW)   # traps (#941, #944): the set pieces, and the carried kits named fish_trap and bird_trap
ITEMS["bird_trap_set"] = ("bird_trap_set", STATION_VIEW)
ITEMS["fish_trap"] = (fish_trap_kit, STATION_VIEW)
ITEMS["bird_trap"] = (bird_trap_kit, rot_y(math.radians(-20.0)) @ rot_x(math.radians(20.0)))
ITEMS["iron_anvil"] = ("iron_anvil", STATION_VIEW)   # the forge add-on (#950), and its kit
ITEMS["iron_anvil_kit"] = ("iron_anvil", STATION_VIEW)
ITEMS["preserving_jar"] = ("preserving_jar", STATION_VIEW)   # C7 (#955): the pickling crock and the root cellar, and their kits
ITEMS["preserving_jar_kit"] = ("preserving_jar", STATION_VIEW)
ITEMS["root_cellar"] = ("root_cellar", rot_y(math.radians(-20.0)) @ rot_x(math.radians(18.0)))
ITEMS["root_cellar_kit"] = ("root_cellar", rot_y(math.radians(-20.0)) @ rot_x(math.radians(18.0)))
ITEMS["log_shelf"] = ("log_shelf", STATION_VIEW)   # B3b: the Log - Shelf, Iron - Chest and Wooden - Crate (blueprint pieces, no kits)
ITEMS["iron_chest"] = ("iron_chest", FURNITURE_VIEW)
ITEMS["wooden_crate"] = ("wooden_crate", FURNITURE_VIEW)
for _tier in ("engineered", "fortified"):   # the seven-tier ladder's concrete tiers (10 Nov 2026); Fortified is the same model with iron bands
    for _piece, _view in (("foundation", SLAB_VIEW), ("wall", WALL_VIEW), ("doorway", WALL_VIEW), ("pillar", STATION_VIEW)):
        ITEMS[_tier + "_" + _piece] = (_tier + "_" + _piece + ("_open" if _piece == "doorway" else ""), _view)
ITEMS["engineered_window"] = ("engineered_window", WALL_VIEW)
ITEMS["engineered_stairs"] = ("engineered_stairs", STAIR_VIEW)
ITEMS["engineered_floor"] = ("engineered_floor", SLAB_VIEW)
ITEMS["engineered_roof_corner"] = ("engineered_roof_corner", CORNER_VIEW)
ITEMS["fortified_gate"] = ("fortified_gate", WALL_VIEW)
ITEMS["fortified_wall_top"] = ("fortified_wall_top", WALL_VIEW)
ITEMS["mixer"] = ("mixer", STATION_VIEW)
ITEMS["log_workbench"] = ("carpenters_bench", STATION_VIEW)   # the level-2 workbench, renamed Carpenter's bench (#966); the id stays
for _item in ("chicken_coop", "fodder_trough", "tub", "sap_tap", "cheese_press", "spinning_wheel", "loom"):   # C7 future placeholders
    ITEMS[_item] = (_item, STATION_VIEW)
ITEMS["tub"] = ("tub", STATION_VIEW @ rot_x(math.radians(22.0)))   # tipped toward the viewer so the water shows
ITEMS["wooden_lantern"] = (lambda: carried_lantern(False), STATION_VIEW)
ITEMS["iron_lantern"] = (lambda: carried_lantern(True), STATION_VIEW)
NAMES = tuple(ITEMS)
LIFT = ()   # too dark to read on the slot: brightened after the render (as paint_structure_icons LIFT)

# Tall thin pieces would be a hairline in a square icon, so their shaft is drawn shorter: (keep at the foot m, keep at the top m, the rest
# scaled by). The foot and the head (a capital, a lantern, a torch) keep their true shape; only the plain shaft between is shortened.
SHORTEN = {
    "thatch_pillar": (0.35, 0.4, 0.3), "wooden_pillar": (0.35, 0.4, 0.3), "log_pillar": (0.35, 0.4, 0.3), "stone_pillar": (0.35, 0.4, 0.3),
    "brick_pillar": (0.35, 0.4, 0.3), "wooden_torch_post": (0.3, 0.6, 0.3), "stone_torch_pillar": (0.3, 0.6, 0.35), "iron_torch_stand": (0.35, 0.6, 0.3),
    "wooden_lamp_post": (0.3, 0.8, 0.12), "iron_lamp_post": (0.35, 0.8, 0.12), "stone_lamp_post": (0.35, 0.8, 0.12), "thatch_scarecrow": (0.1, 1.2, 0.4),
    "armour_stand": (0.1, 0.95, 0.5),
}


def _shortener(top, keep):
    foot, head, k = keep
    mid = top - head - foot
    return lambda y: y if y <= foot else (foot + (y - foot) * k if y <= top - head else y - mid * (1.0 - k))


def _lit(look, squeeze):
    """The look's flames where lit_fixture draws them (PieceLook.LIGHT_SPOTS), for the torches and braziers: a lit torch is how it is known.
    The lanterns and lamps draw their own lit panes, so they need none."""
    spots = look_runtime.looks() and look_runtime._space.get("LIGHT_SPOTS", {}).get(look)

    if not spots or spots["spots"][0][1].y < 0.5:
        return []

    at, size = spots["spots"][0]
    return flame(at.x, squeeze(at.y) - size.y * 0.25, at.z, size.y * 0.5)


def paint(item):
    look, view = ITEMS[item]
    faces = look_runtime.faces_of(look() if callable(look) else look_runtime.build(look))
    squeeze = lambda y: y

    if item in SHORTEN:
        top = max(p[1] for pts, _ in faces for p in pts)
        squeeze = _shortener(top, SHORTEN[item])
        faces = [([np.array([p[0], squeeze(p[1]), p[2]]) for p in pts], colour) for pts, colour in faces]

    faces += [] if callable(look) else _lit(look, squeeze)
    icon = render(faces, view, colour_jitter=0.04, seed=len(item))
    return lift_dark(icon) if item in LIFT else icon


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "item_icons"))
    parser.add_argument("--only", default="")
    parser.add_argument("--sheet", default="", help="also save a contact sheet of what was painted, on the slot colour")
    args = parser.parse_args()
    only = set(filter(None, args.only.split(",")))
    done = []

    for item in ITEMS:
        if only and item not in only:
            continue

        icon = paint(item)
        path = os.path.join(args.out, item + ".png")
        icon.save(path)
        done.append(icon)
        print("painted", path)

    if args.sheet and done:
        cols = 10
        sheet = Image.new("RGBA", (128 * cols, 128 * ((len(done) + cols - 1) // cols)), (0x2A, 0x1F, 0x16, 255))

        for k, icon in enumerate(done):
            sheet.alpha_composite(icon, ((k % cols) * 128, (k // cols) * 128))

        sheet.save(args.sheet)


if __name__ == "__main__":
    main()
