#!/usr/bin/env python3
"""Tests for tools/nightly_backup.py on fake trees in a temp folder. Never touches E: or the real project.
Run: python tools/test_nightly_backup.py   (prints "nightly backup: N failures", exit code = N > 0)"""
import datetime, os, random, shutil, sys, tempfile, types, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nightly_backup as nb

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("FAIL:", msg)


def nm(d, hhmm="2330"):
    return "DynastyALWL_ProjectBackup_%s_%s.zip" % (d.isoformat(), hhmm)


def quiet(_msg):
    pass


# ---------- name pattern ----------
def test_names():
    good = nm(datetime.date(2026, 10, 22))
    check(nb.parse_name(good) == (datetime.date(2026, 10, 22), "2330"), "valid name parses")
    for bad in ["notes.txt", good + ".partial", "X_" + good, good.replace("2026-10-22", "2026-1-22"),
                nm(datetime.date(2026, 10, 22)).replace("2026-10-22", "2026-02-30"), good.replace(".zip", ".ZIP"),
                good.replace("DynastyALWL", "dynastyalwl"), " " + good, good.replace("_2330", "_233"), "backup_log.txt"]:
        check(nb.parse_name(bad) is None, "junk name rejected: " + bad)


# ---------- cull on in-memory entries ----------
def entries_for(dates):
    return [(nm(d), d) for d in dates]


def test_plan_basic():
    today = datetime.date(2026, 10, 22)
    dates = [today - datetime.timedelta(days=i) for i in range(0, 40)]
    actions, alerts, _ = nb.plan_cull(entries_for(dates), today, (), max_moves=100)
    moved = {a[0] for a in actions}
    for d in dates:
        age = (today - d).days
        if age <= 30:
            check(nm(d) not in moved, "never within 30 days: " + str(d))
    check(nm(today) not in moved, "never the newest")
    check(len(actions) > 0, "old zips are planned")
    # every old week keeps exactly one survivor: the planned moves never remove the last zip of a week without weekly
    for a in actions:
        if a[1] == "trash":
            wk = a[2]
            others = [d for d in dates if nm(d) not in moved or any(x[0] == nm(d) and x[1] == "weekly" for x in actions)]
            check(any("%d-W%02d" % nb.iso_week(d) == wk for d in others), "trash keeps a survivor of week " + wk)


def test_plan_never_below_30():
    today = datetime.date(2026, 10, 22)
    dates = [today - datetime.timedelta(days=i * 3) for i in range(0, 30)]     # 30 zips, spanning 87 days
    actions, _, _ = nb.plan_cull(entries_for(dates), today, (), max_moves=100)
    check(actions == [], "30 zips or fewer: nothing is removed (%d planned)" % len(actions))
    dates.append(today - datetime.timedelta(days=100))
    actions, _, _ = nb.plan_cull(entries_for(dates), today, (), max_moves=100)
    check(len(actions) == 1, "31 zips: exactly the oldest goes")


def test_plan_cap_and_alerts():
    today = datetime.date(2026, 10, 22)
    old = [today - datetime.timedelta(days=60 + i) for i in range(10)]
    keep = [today - datetime.timedelta(days=i) for i in range(31)]
    actions, alerts, _ = nb.plan_cull(entries_for(old + keep), today, (), max_moves=3)
    check(actions == [] and any("cap 3" in a for a in alerts), "more than 3 would-be moves: nothing moved and an alert")
    actions, alerts, _ = nb.plan_cull(entries_for(old[:2] + keep), today, (), max_moves=3)
    check(len(actions) == 2 and not alerts, "2 moves are allowed")
    # mtime mismatch: 3 days apart is skipped with an alert and counts as kept
    e = entries_for(old[:1] + keep)
    e[0] = (e[0][0], old[0] + datetime.timedelta(days=3))
    actions, alerts, _ = nb.plan_cull(e, today, (), max_moves=3)
    check(actions == [] and any("disagree" in a for a in alerts), "name/mtime 3 days apart: skipped with alert")
    e[0] = (e[0][0], old[0] + datetime.timedelta(days=2))
    actions, alerts, _ = nb.plan_cull(e, today, (), max_moves=3)
    check(len(actions) == 1, "name/mtime 2 days apart is fine")


def test_plan_junk_and_weekly():
    today = datetime.date(2026, 10, 22)
    keep = [today - datetime.timedelta(days=i) for i in range(31)]
    junk = [("notes.txt", today), ("backup_log.txt", today), (nm(today) + ".partial", today),
            ("DynastyALWL_ProjectBackup_2026-02-30_0000.zip", today)]
    old = datetime.date(2026, 8, 1)
    actions, _, ignored = nb.plan_cull(entries_for(keep + [old]) + junk, today, (), max_moves=5)
    check(len(ignored) == 4, "four junk files ignored and listed")
    check(actions == [(nm(old), "weekly", "2026-W31")], "lone old zip goes to weekly: %s" % actions)
    actions, _, _ = nb.plan_cull(entries_for(keep + [old]), today, (nm(old, "0100"),), max_moves=5)
    check(actions == [(nm(old), "trash", "2026-W31")], "week already in weekly: goes to trash")


def test_iso_weeks():
    check(nb.iso_week(datetime.date(2026, 12, 31)) == (2026, 53), "2026-12-31 is week 53")
    check(nb.iso_week(datetime.date(2027, 1, 1)) == (2026, 53), "2027-01-01 is still 2026 W53")
    check(nb.iso_week(datetime.date(2027, 1, 4)) == (2027, 1), "2027-01-04 is 2027 W01")
    check(nb.iso_week(datetime.date(2025, 12, 29)) == (2026, 1), "2025-12-29 is 2026 W01")
    # a lone zip on a week-boundary pair: Sunday and Monday are different weeks
    check(nb.iso_week(datetime.date(2026, 10, 25)) != nb.iso_week(datetime.date(2026, 10, 26)), "Sunday and Monday differ")


# ---------- a year of nights on a real (temp) folder ----------
def test_year_simulation(tmp):
    dest = os.path.join(tmp, "year")
    os.makedirs(dest)
    rnd = random.Random(7)
    start = datetime.date(2026, 1, 1)           # covers DST (US 03-08, 11-01; EU 03-29, 10-25), W53 of 2026, W01 of 2027
    created, weekly_seen = [], set()
    skip_run = 0
    for day in range(0, 400):
        today = start + datetime.timedelta(days=day)
        if skip_run:
            skip_run -= 1
            continue
        if rnd.random() < 0.15:
            skip_run = rnd.choice([0, 1])       # a missed night, sometimes two in a row (more would trip the cap, tested above)
            if skip_run == 0:
                continue
            continue
        path = os.path.join(dest, nm(today))
        open(path, "w").write("x")
        ts = datetime.datetime(today.year, today.month, today.day, 23, 30).timestamp()
        os.utime(path, (ts, ts))
        created.append(today)
        with open(os.path.join(dest, "backup_log.txt"), "a") as f:
            f.write("log\n")
        open(os.path.join(dest, "notes.txt"), "w").write("keep me")
        now_ts = datetime.datetime(today.year, today.month, today.day, 23, 59).timestamp()
        n, alerts = nb.do_cull(dest, today, True, nb.MAX_MOVES, quiet, now=now_ts)
        check(not alerts, "no alerts on day %s: %s" % (today, alerts))
        root = {x for x in os.listdir(dest) if nb.parse_name(x)}
        check(nm(today) in root, "newest zip present on " + str(today))
        for d in created:
            if (today - d).days <= 30:
                check(nm(d) in root, "zip within 30 days kept: %s on %s" % (d, today))
        weekly = set(os.listdir(os.path.join(dest, "weekly"))) if os.path.isdir(os.path.join(dest, "weekly")) else set()
        check(weekly_seen <= weekly, "weekly\\ never loses a file on " + str(today))
        weekly_seen = weekly
        check(os.path.exists(os.path.join(dest, "notes.txt")) and os.path.exists(os.path.join(dest, "backup_log.txt")), "junk files untouched")
    weeks_created = {nb.iso_week(d) for d in created}
    survivors = set()
    for folder in (dest, os.path.join(dest, "weekly")):
        if os.path.isdir(folder):
            for x in os.listdir(folder):
                p = nb.parse_name(x)
                if p:
                    survivors.add(nb.iso_week(p[0]))
    check(weeks_created <= survivors, "every ISO week with a backup still has a survivor: missing %s" % sorted(weeks_created - survivors))
    check((2026, 53) in survivors and len(created) > 300, "week 53 present, simulation ran")
    root_count = len([x for x in os.listdir(dest) if nb.parse_name(x)])
    check(30 <= root_count <= 33, "root holds about 30 zips, has %d" % root_count)
    trash = os.path.join(dest, "_trash")
    check(not os.path.isdir(trash) or len(os.listdir(trash)) <= 10, "trash stays small (empties after 7 days)")


def test_dry_run_moves_nothing(tmp):
    dest = os.path.join(tmp, "dry")
    os.makedirs(dest)
    today = datetime.date(2026, 10, 22)
    for i in list(range(0, 31)) + [60]:
        d = today - datetime.timedelta(days=i)
        p = os.path.join(dest, nm(d))
        open(p, "w").write("x")
        ts = datetime.datetime(d.year, d.month, d.day, 12).timestamp()
        os.utime(p, (ts, ts))
    before = sorted(os.listdir(dest))
    logs = []
    n, _ = nb.do_cull(dest, today, False, 3, logs.append)
    check(sorted(os.listdir(dest)) == before, "dry-run changes nothing on disk")
    check(n == 1 and any("DRY-RUN would move" in l for l in logs), "dry-run logs what it would do")


def test_trash_purge(tmp):
    dest = os.path.join(tmp, "trash")
    os.makedirs(os.path.join(dest, "_trash"))
    today = datetime.date(2026, 10, 22)
    old, fresh, junk = nm(datetime.date(2026, 8, 1)), nm(datetime.date(2026, 8, 2)), "keep.txt"
    for n in (old, fresh, junk):
        open(os.path.join(dest, "_trash", n), "w").write("x")
    now = datetime.datetime(2026, 10, 22, 12).timestamp()
    os.utime(os.path.join(dest, "_trash", old), (now - 8 * 86400, now - 8 * 86400))
    os.utime(os.path.join(dest, "_trash", fresh), (now - 6 * 86400, now - 6 * 86400))
    nb.do_cull(dest, today, True, 3, quiet, now=now)
    left = set(os.listdir(os.path.join(dest, "_trash")))
    check(left == {fresh, junk}, "trash empties only valid names older than 7 days: %s" % left)


# ---------- end to end on a fake project ----------
def make_cfg(tmp, name):
    src, saves, dest = (os.path.join(tmp, name, x) for x in ("proj", "saves", "dest"))
    os.makedirs(os.path.join(src, ".git", "objects", "ab"))
    os.makedirs(os.path.join(src, "worlds", "base_world", "tiles"))
    os.makedirs(os.path.join(src, "crash_reports"))
    os.makedirs(os.path.join(src, ".godot"))
    os.makedirs(os.path.join(saves, "Island"))
    for rel, data in (("project.godot", "x=1"), (".git/HEAD", "ref: refs/heads/main"), (".git/objects/ab/cdef", "blob"),
                      ("worlds/base_world/tiles/tile_3_4.tile", "tile"), ("crash_reports/a.txt", "crash"), (".godot/cache.bin", "c"),
                      ("~libwatercore.dll", "tmp"), ("junk.tmp", "t"), ("readme.md", "hello")):
        with open(os.path.join(src, *rel.split("/")), "w") as f:
            f.write(data)
    with open(os.path.join(saves, "Island", "world.sqlite"), "w") as f:
        f.write("save")
    cfg = types.SimpleNamespace(src=src, saves=saves, dest=dest, godot="none", cull_live=False, cull_only=False,
                                preflight_only=False, no_restore_test=True, max_moves=3, margin=0)
    return cfg


def test_end_to_end(tmp):
    cfg = make_cfg(tmp, "e2e")
    now = datetime.datetime(2026, 10, 22, 23, 30)
    res = nb.run(cfg, now=now, game_running_fn=lambda: False, free_fn=lambda p: 10 ** 12)
    check(res.startswith("Backup done: DynastyALWL_ProjectBackup_2026-10-22_2330.zip"), "backup reports done: " + res)
    zp = os.path.join(cfg.dest, "DynastyALWL_ProjectBackup_2026-10-22_2330.zip")
    check(os.path.isfile(zp) and not os.path.exists(zp + ".partial"), "zip exists, no .partial left")
    with zipfile.ZipFile(zp) as z:
        names = set(z.namelist())
    for need in ("DynastyALWL/project.godot", "DynastyALWL/.git/HEAD", "DynastyALWL/worlds/base_world/tiles/tile_3_4.tile",
                 "server_store/Island/world.sqlite", "BACKUP_MANIFEST.json", "DynastyALWL/readme.md"):
        check(need in names, "zip has " + need)
    for no in ("DynastyALWL/crash_reports/a.txt", "DynastyALWL/.godot/cache.bin", "DynastyALWL/~libwatercore.dll", "DynastyALWL/junk.tmp"):
        check(no not in names, "zip excludes " + no)
    check(os.path.isfile(os.path.join(cfg.dest, "LAST_BACKUP_OK.txt")) and os.path.isfile(os.path.join(cfg.dest, "backup_status.json")), "status files written")
    # same minute again: name collision fails, nothing overwritten
    size = os.path.getsize(zp)
    try:
        nb.run(cfg, now=now, game_running_fn=lambda: False, free_fn=lambda p: 10 ** 12)
        check(False, "collision should fail")
    except nb.BackupError as e:
        check("already exists" in e.reason or "clock" in e.reason, "collision refused: " + e.reason)
    check(os.path.getsize(zp) == size, "old zip untouched after refused run")
    # clock earlier than the newest zip
    try:
        nb.run(cfg, now=datetime.datetime(2026, 10, 21, 23, 30), game_running_fn=lambda: False, free_fn=lambda p: 10 ** 12)
        check(False, "old clock should fail")
    except nb.BackupError as e:
        check("clock" in e.reason, "clock going backwards refused")


def expect_fail(cfg, now, word, **kw):
    try:
        nb.run(cfg, now=now, **kw)
        check(False, "should fail: " + word)
    except nb.BackupError as e:
        check(word in e.reason, "fails with '%s', got '%s'" % (word, e.reason))


def test_preflight_failures(tmp):
    now = datetime.datetime(2026, 10, 22, 23, 30)
    cfg = make_cfg(tmp, "pf")
    ok_free, ok_game = (lambda p: 10 ** 12), (lambda: False)
    expect_fail(cfg, now, "running", game_running_fn=lambda: True, free_fn=ok_free)
    expect_fail(cfg, now, "space", game_running_fn=ok_game, free_fn=lambda p: 1000)
    open(os.path.join(cfg.src, ".git", "index.lock"), "w").close()
    expect_fail(cfg, now, "index.lock", game_running_fn=ok_game, free_fn=ok_free)
    os.remove(os.path.join(cfg.src, ".git", "index.lock"))
    shutil.rmtree(cfg.saves)
    expect_fail(cfg, now, "save folder missing", game_running_fn=ok_game, free_fn=ok_free)
    check(not [x for x in os.listdir(cfg.dest) if x.endswith((".zip", ".partial"))], "failed preflights write no zip")
    cfg2 = make_cfg(tmp, "pf2")
    os.remove(os.path.join(cfg2.src, "worlds", "base_world", "tiles", "tile_3_4.tile"))
    expect_fail(cfg2, now, "required path missing", game_running_fn=ok_game, free_fn=ok_free)
    check(not [x for x in os.listdir(cfg2.dest) if x.endswith((".zip", ".partial"))], "failed verify leaves no zip or .partial")
    cfg3 = make_cfg(tmp, "pf3")
    cfg3.preflight_only = True
    res = nb.run(cfg3, now=now, game_running_fn=ok_game, free_fn=ok_free)
    check(res.startswith("Preflight OK") and not [x for x in os.listdir(cfg3.dest) if x.endswith(".zip")], "--preflight writes nothing")


def main():
    tmp = tempfile.mkdtemp(prefix="nbtest_")
    assert not tmp.upper().startswith("E:"), "tests must never run on E:"
    try:
        test_names()
        test_plan_basic()
        test_plan_never_below_30()
        test_plan_cap_and_alerts()
        test_plan_junk_and_weekly()
        test_iso_weeks()
        test_year_simulation(tmp)
        test_dry_run_moves_nothing(tmp)
        test_trash_purge(tmp)
        test_end_to_end(tmp)
        test_preflight_failures(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("nightly backup: %d failures" % len(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
