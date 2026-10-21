#!/usr/bin/env python3
"""Skill web progression simulation (SKILLS_WEB_DESIGN.md, Tyler's numbers). Prints real hours of play to reach each value for
skills of depth 0, 1 and 2, untrained and with training, at the per-game-day practice cap. No game code is touched.

Run: python3 tools/skills_sim.py [--day-cap 300] [--base 40] [--growth 1.045] [--gen 1.5] [--cap-step 25] [--train-speed 1.2]
A game day is one real hour (clock ratio 24:1), so practice per real hour = the per-game-day cap.
"""
import argparse


def cost(n, base, growth, gen, depth):
    """Practice points to go from value n to n + 1."""
    return base * growth ** (n - 1) * gen ** depth


def simulate(depth, args, trait=0.0):
    hours = 0.0
    value = 1
    points = 0.0
    rows = {}
    train = 0
    speed = 1.0 + trait * 0.01

    while value < 100:
        cap = args.cap_step * (1 + train)

        if value >= cap:
            train += 1      # a teacher is found the moment the cap is hit: the wait for training is not counted
            speed *= args.train_speed
            value = min(value, cap)
            cap = args.cap_step * (1 + train)
            value = max(value, cap - args.cap_step + 5)

        need = cost(value, args.base, args.growth, args.gen, depth)
        slow = min(1.0, (cap - value) / 6.0 + 0.25)         # smooth slow-down in the last points under the cap
        step_hours = need / (args.day_cap * speed * slow)
        hours += step_hours
        points += need
        value += 1

        if value in (15, 25, 40, 50, 65, 75, 90, 100):
            rows[value] = (hours, points)

    return rows


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--day-cap", type=float, default=300.0)
    p.add_argument("--base", type=float, default=40.0)
    p.add_argument("--growth", type=float, default=1.045)
    p.add_argument("--gen", type=float, default=1.5)
    p.add_argument("--cap-step", type=int, default=25)
    p.add_argument("--train-speed", type=float, default=1.2)
    args = p.parse_args()
    print("value   depth0 hours   depth1 hours   depth2 hours   (points, depth 0)")
    tables = [simulate(d, args) for d in (0, 1, 2)]

    for v in (15, 25, 40, 50, 65, 75, 90, 100):
        print("%5d   %12.0f   %12.0f   %12.0f   %9.0f" % (v, tables[0][v][0], tables[1][v][0], tables[2][v][0], tables[0][v][1]))

    low = simulate(0, args, trait=-30.0)[100][0]
    high = simulate(0, args, trait=30.0)[100][0]
    print("trait -10 / +10 (+/-30 percent speed) to 100 at depth 0: %.0f h / %.0f h" % (low, high))


if __name__ == "__main__":
    main()
