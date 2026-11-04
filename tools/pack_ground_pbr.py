#!/usr/bin/env python3
"""Packs Mike's CC0 ambientCG ground sets (assets/pbr/ground/<set>_{color,normal,rough}.jpg) into one RGBA PNG per set
for src/client/ground_material.gd: R = colour brightness (the shader multiplies the soil colour by it), G = normal x, B = normal y
(OpenGL, as in the sources), A = roughness. Run: python3 tools/pack_ground_pbr.py  (needs numpy and Pillow).
Prints each set's mean and spread of R, for LAYER_MEAN and LAYER_STRENGTH in ground_material.gd."""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "pbr", "ground")
OLD = os.path.join(HERE, "..", "assets", "ground")
SETS = {"turf": "layer_0_turf", "litter": "layer_1_litter", "gravel": "layer_2_gravel", "mud_sand": "layer_3_mud", "rock": "layer_5_rock"}

for name, old_name in SETS.items():
    color = np.asarray(Image.open(os.path.join(SRC, name + "_color.jpg")).convert("RGB"), dtype=np.float32) / 255.0
    normal = np.asarray(Image.open(os.path.join(SRC, name + "_normal.jpg")).convert("RGB"), dtype=np.uint8)
    rough = np.asarray(Image.open(os.path.join(SRC, name + "_rough.jpg")).convert("L"), dtype=np.uint8)
    luma = color @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    pack = np.dstack([np.clip(luma * 255.0, 0, 255).astype(np.uint8), normal[..., 0], normal[..., 1], rough])
    Image.fromarray(pack, "RGBA").save(os.path.join(SRC, name + "_pack.png"), optimize=True)
    old = np.asarray(Image.open(os.path.join(OLD, old_name + ".png")).convert("RGBA"), dtype=np.float32)[..., 0] / 255.0
    print("%-9s new R mean %.3f std %.3f | old R mean %.3f std %.3f | rough mean %.3f" % (name, luma.mean(), luma.std(), old.mean(), old.std(), rough.mean() / 255.0))
