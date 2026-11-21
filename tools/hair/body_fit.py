#!/usr/bin/env python3
"""The hair fit of a body model: the scale and offset that carry Body 1's skull onto that body's skull, in model space (metres, +Y up, facing +Z).

Hair meshes (tools/hair/prepare_hair.py) are fitted to Body 1's head. Another body wears them through this one box fit, written into its row of
src/client/character/body_models.gd as "hair_fit": hair point on this body = Body 1 point * scale + offset. The box is the skull above the
ears (from SKULL_DROP_M under the crown up), so ears, faces and jaws do not move it; height scales with the mean of width and depth.

Usage: python3 -I tools/hair/body_fit.py assets/character/Humanoid/Playercharacter_Female_01.glb [--male assets/character/Humanoid/Dynasty_Base_Male.glb]
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prepare_hair import Glb  # noqa: E402

SKULL_DROP_M = 0.09      # Body 1: crown 1.700, skull above the ears from about 1.61 (bald head FITTING_NOTE.md)


def skull_box(path):
    points = Glb(path).positions()
    crown = points[:, 1].max()
    skull = points[points[:, 1] >= crown - SKULL_DROP_M]
    return skull.min(0), skull.max(0), crown


def fit(male_path, body_path):
    """scale, offset: Body 1 model space -> this body's, by the skull boxes."""
    m_lo, m_hi, m_crown = skull_box(male_path)
    b_lo, b_hi, b_crown = skull_box(body_path)
    sx = (b_hi[0] - b_lo[0]) / (m_hi[0] - m_lo[0])
    sz = (b_hi[2] - b_lo[2]) / (m_hi[2] - m_lo[2])
    scale = np.array([sx, 0.5 * (sx + sz), sz])
    offset = np.array([
        0.5 * (b_lo[0] + b_hi[0]) - scale[0] * 0.5 * (m_lo[0] + m_hi[0]),
        b_crown - scale[1] * m_crown,
        0.5 * (b_lo[2] + b_hi[2]) - scale[2] * 0.5 * (m_lo[2] + m_hi[2]),
    ])
    return scale, offset


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("body")
    parser.add_argument("--male", default="assets/character/Humanoid/Dynasty_Base_Male.glb")
    args = parser.parse_args()
    scale, offset = fit(args.male, args.body)
    print('"hair_fit": {"scale": Vector3(%.4f, %.4f, %.4f), "offset": Vector3(%.4f, %.4f, %.4f)}' % (*scale, *offset))


if __name__ == "__main__":
    main()
