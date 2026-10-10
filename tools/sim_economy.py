"""Economy pacing simulator for Go Viral (design tool, not shipped).

Mirrors src/shared/Config/*.luau and src/shared/Economy.luau. If you change
numbers there, change them here and re-run:  python3 tools/sim_economy.py

Models an *active, efficient* player with average timing skill who buys the
cheapest upgrade the moment they can afford it and rebrands the moment it is
unlocked. Real players spend time in menus, chatting and exploring, so expect
real-world pacing to be roughly 2x slower than this output.
"""
import math

BASE_VIEWS = 10
FOLLOW_RATE = 0.08
CASH_RATE = 0.2
SECONDS_PER_POST = 2.2          # take + cooldown + human reaction
AVG_TAKE_MULT = 1.3             # mix of Miss 1.0 / Good 1.25 / Perfect 1.6
TREND_AVG_MULT = 1.3            # trend x2 matches ~30% of the time
REBRAND_BASE = 1_000_000        # followers needed for rebrand #1
REBRAND_GROWTH = 4              # each rebrand needs 4x the previous
REBRAND_BONUS = 0.5             # +50% views per rebrand, forever
NEW_CREATOR_THRESHOLD = 250     # x3 followers until this many lifetime followers
NEW_CREATOR_BONUS = 3

# (multiplier, cash cost)
CAMERA = [(1, 0), (1.6, 50), (2.5, 600), (4, 6_000), (6.5, 60_000), (10, 600_000),
          (16, 6_000_000), (25, 80_000_000), (40, 1_500_000_000), (65, 30_000_000_000)]
LIGHTING = [(1, 0), (1.25, 200), (1.6, 3_000), (2.1, 35_000), (2.8, 400_000),
            (3.8, 4_500_000), (5.2, 80_000_000), (7, 1_800_000_000)]
SET = [(1, 0), (1.3, 800), (1.75, 12_000), (2.4, 150_000), (3.3, 1_800_000),
       (4.6, 20_000_000), (6.5, 400_000_000), (9, 9_000_000_000)]
# (name, multiplier, followers needed, cash cost)
NICHES = [("Vlogs", 1, 0, 0), ("Gaming", 1.5, 250, 500), ("Dance", 2.2, 5_000, 10_000),
          ("Cooking", 3.2, 60_000, 150_000), ("Challenges", 4.5, 500_000, 2_000_000),
          ("Fitness", 6.5, 5_000_000, 25_000_000), ("Music", 9.5, 50_000_000, 300_000_000)]


def reach_mult(followers):
    return 1 + 0.35 * math.log10(1 + followers)


def run(checkpoints=(0.25, 1, 5, 20, 100)):
    tracks = {"Camera": CAMERA, "Lighting": LIGHTING, "Set": SET}
    t = cash = followers = lifetime = 0.0
    rebrands = 0
    gear = {k: 0 for k in tracks}
    niche = 1
    first_upgrade = first_rebrand = None
    rows, pending = [], list(checkpoints)
    while pending:
        mult = (CAMERA[gear["Camera"]][0] * LIGHTING[gear["Lighting"]][0] * SET[gear["Set"]][0]
                * NICHES[niche - 1][1] * AVG_TAKE_MULT * TREND_AVG_MULT
                * reach_mult(followers) * (1 + REBRAND_BONUS * rebrands))
        views = BASE_VIEWS * mult
        cash += views * CASH_RATE
        buzz = NEW_CREATOR_BONUS if lifetime < NEW_CREATOR_THRESHOLD else 1
        gained = max(1.0, views * FOLLOW_RATE * buzz)
        followers += gained
        lifetime += gained
        t += SECONDS_PER_POST

        if niche < len(NICHES):
            _, _, need, cost = NICHES[niche]
            if followers >= need and cash >= cost:
                cash -= cost
                niche += 1

        options = [(k, tr[gear[k] + 1][1]) for k, tr in tracks.items() if gear[k] + 1 < len(tr)]
        if options:
            k, cost = min(options, key=lambda o: o[1])
            if cash >= cost:
                cash -= cost
                gear[k] += 1
                first_upgrade = first_upgrade or t

        if followers >= REBRAND_BASE * REBRAND_GROWTH ** rebrands:
            rebrands += 1
            cash = followers = 0.0
            gear = {k: 0 for k in tracks}
            first_rebrand = first_rebrand or t

        if t >= pending[0] * 3600:
            rows.append((pending.pop(0), followers, lifetime, dict(gear), NICHES[niche - 1][0], rebrands))
    return first_upgrade, first_rebrand, rows


if __name__ == "__main__":
    first_upgrade, first_rebrand, rows = run()
    print(f"First upgrade after {first_upgrade:.0f}s; first rebrand after {first_rebrand / 3600:.1f}h (sim time)")
    print(f"{'Hour':>5} | {'Followers':>15} | {'Lifetime':>16} | Cam Lit Set | {'Top niche':<10} | Rebrands")
    for h, f, lf, g, n, rb in rows:
        print(f"{h:>5} | {f:>15,.0f} | {lf:>16,.0f} | {g['Camera'] + 1:>3} {g['Lighting'] + 1:>3} "
              f"{g['Set'] + 1:>3} | {n:<10} | {rb:>3}")
