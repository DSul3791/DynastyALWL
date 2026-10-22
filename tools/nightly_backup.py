#!/usr/bin/env python3
"""Nightly project backup for Dave's PC (BP-C110; plan: docs/mirror/tech/BACKUP_PLAN.md, restore: RESTORE_PROCEDURE.md).

  python tools/nightly_backup.py                  full run: preflight, zip, verify, restore test, cull (cull is DRY-RUN)
  python tools/nightly_backup.py --cull-live      same, but the cull really moves files (only after 14 good dry-run nights)
  python tools/nightly_backup.py --preflight      only the preflight checks, writes nothing
  python tools/nightly_backup.py --cull-only      only the cull (dry-run unless --cull-live)
  --max-moves N                                   manual override of the 3-moves-per-run cap (Dave present)

Prints one last line: "Backup done: ..." or "Backup FAILED: <step>, <reason>" (exit code 0 / 1).
The zip holds the project folder (incl .git) under DynastyALWL/ and the save folder under server_store/.
"""
import argparse, ctypes, datetime, fnmatch, hashlib, json, os, re, shutil, subprocess, sys, time, zipfile

VERSION = "1"
NAME_RE = re.compile(r"^DynastyALWL_ProjectBackup_(\d{4})-(\d{2})-(\d{2})_(\d{4})\.zip$")
DEFAULT_SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SAVES = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Dynasty a life well lived", "server_store")
DEFAULT_DEST = r"E:\Software\godotDev\DynastyALWL_ProjectBackups"
DEFAULT_GODOT = r"C:\GodotInstaller\godot.windows.editor.x86_64.exe"
PROJECT_PREFIX = "DynastyALWL/"
SAVES_PREFIX = "server_store/"
EXCLUDE_DIRS = {".godot", "crash_reports", "__pycache__"}
EXCLUDE_FILES = ("~libwatercore*", "*.tmp")
REQUIRED = ("DynastyALWL/project.godot", "DynastyALWL/.git/HEAD", "DynastyALWL/worlds/base_world/tiles/tile_3_4.tile", "server_store/")
KEEP_DAYS = 30          # every nightly of the last 30 days is kept, and never fewer than 30 zips
MAX_MOVES = 3           # at most this many zips moved per run, more = stop and alert
TRASH_DAYS = 7
MTIME_SLACK_DAYS = 2
FREE_MARGIN = 5 * 1024 ** 3


class BackupError(Exception):
    def __init__(self, step, reason):
        super().__init__("%s: %s" % (step, reason))
        self.step, self.reason = step, reason


def make_log(dest):
    path = os.path.join(dest, "backup_log.txt")

    def log(msg):
        line = "%s %s" % (datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg)
        print(line)
        try:
            with open(path, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except OSError:
            pass
    return log


# ---------- names and cull rules (pure functions, unit-tested) ----------

def parse_name(name):
    """(date, 'HHMM') for a name matching the strict pattern with a real date, else None."""
    m = NAME_RE.match(name)
    if not m:
        return None
    try:
        return datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3))), m.group(4)
    except ValueError:
        return None


def iso_week(d):
    y, w, _ = d.isocalendar()
    return (y, w)


def plan_cull(entries, today, weekly_names=(), max_moves=MAX_MOVES):
    """entries: (name, mtime_date) of files in the backup folder root. Returns (actions, alerts, ignored).
    actions: (name, 'trash' or 'weekly', iso week). Oldest first; a zip whose ISO week has no other survivor goes
    to weekly\\, else to _trash\\. Never the newest zip, never the last KEEP_DAYS days, never below KEEP_DAYS zips."""
    zips, protected, ignored, alerts = [], [], [], []
    for name, mdate in entries:
        p = parse_name(name)
        if not p:
            ignored.append(name)
        elif abs((mdate - p[0]).days) > MTIME_SLACK_DAYS:
            alerts.append("date in name and file time disagree, skipped: " + name)
            protected.append((p[0], p[1], name))
        else:
            zips.append((p[0], p[1], name))
    zips.sort()
    everything = sorted(zips + protected)
    if not zips:
        return [], alerts, ignored
    newest = zips[-1]
    weekly_weeks = set()
    for n in weekly_names:
        p = parse_name(n)
        if p:
            weekly_weeks.add(iso_week(p[0]))
    removed, actions = set(), []
    remaining = len(everything)
    for z in zips:
        if z == newest or (today - z[0]).days <= KEEP_DAYS:
            continue
        if remaining <= KEEP_DAYS:
            break
        week = iso_week(z[0])
        other = any(y[2] != z[2] and y[2] not in removed and iso_week(y[0]) == week for y in everything)
        kind = "trash" if (other or week in weekly_weeks) else "weekly"
        if kind == "weekly":
            weekly_weeks.add(week)
        removed.add(z[2])
        remaining -= 1
        actions.append((z[2], kind, "%d-W%02d" % week))
    if len(actions) > max_moves:
        alerts.append("cull would move %d zips (cap %d): nothing moved, check the dates and clock" % (len(actions), max_moves))
        actions = []
    return actions, alerts, ignored


def list_root(dest):
    out = []
    for e in os.scandir(dest):
        if e.is_file(follow_symlinks=False):
            out.append((e.name, datetime.date.fromtimestamp(e.stat().st_mtime)))
    return out


def do_cull(dest, today, live, max_moves, log, now=None):
    now = now or time.time()
    weekly_dir, trash_dir = os.path.join(dest, "weekly"), os.path.join(dest, "_trash")
    weekly = os.listdir(weekly_dir) if os.path.isdir(weekly_dir) else []
    actions, alerts, ignored = plan_cull(list_root(dest), today, weekly, max_moves)
    for a in alerts:
        log("CULL ALERT: " + a)
    if ignored:
        log("cull ignores (name does not match): " + ", ".join(sorted(ignored)))
    moved = 0
    for name, kind, week in actions:
        target_dir = weekly_dir if kind == "weekly" else trash_dir
        target = os.path.join(target_dir, name)
        if not live:
            log("CULL DRY-RUN would move %s to %s (week %s)" % (name, kind, week))
            continue
        if os.path.exists(target):
            alerts.append("target exists, not moved: " + target)
            log("CULL ALERT: target exists, not moved: " + target)
            continue
        os.makedirs(target_dir, exist_ok=True)
        os.replace(os.path.join(dest, name), target)
        if kind == "trash":
            os.utime(target, None)      # trash age counts from the move
        moved += 1
        log("CULL moved %s to %s (week %s)" % (name, kind, week))
    if os.path.isdir(trash_dir):
        for name in os.listdir(trash_dir):
            path = os.path.join(trash_dir, name)
            if parse_name(name) and os.path.isfile(path) and now - os.path.getmtime(path) > TRASH_DAYS * 86400:
                if live:
                    os.remove(path)
                    log("CULL emptied from _trash (older than %d days): %s" % (TRASH_DAYS, name))
                else:
                    log("CULL DRY-RUN would empty from _trash: " + name)
    return (moved if live else len(actions)), alerts


# ---------- backup steps ----------

def newest_zip(dest):
    best = None
    for name, _ in list_root(dest):
        p = parse_name(name)
        if p and (best is None or (p[0], p[1]) > best[0]):
            best = ((p[0], p[1]), name)
    if not best:
        return None
    d, hhmm = best[0]
    stamp = datetime.datetime(d.year, d.month, d.day, int(hhmm[:2]), int(hhmm[2:]))
    return best[1], stamp, os.path.getsize(os.path.join(dest, best[1]))


def game_running():
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        raise BackupError("preflight", "cannot list processes to check that the game is closed")
    names = [l.split('","')[0].strip('"').lower() for l in out.splitlines() if l]
    return any(n.startswith("godot") or "dynasty" in n for n in names)


def preflight(cfg, log, now, game_running_fn, free_fn):
    if not os.path.isdir(cfg.src):
        raise BackupError("preflight", "project folder missing: " + cfg.src)
    if not os.path.isdir(cfg.saves):
        raise BackupError("preflight", "save folder missing: " + cfg.saves)
    drive = os.path.splitdrive(os.path.abspath(cfg.dest))[0]
    if drive and not os.path.isdir(drive + "\\"):
        raise BackupError("preflight", "drive %s is not there (no fallback to another drive)" % drive)
    os.makedirs(cfg.dest, exist_ok=True)
    if game_running_fn():
        raise BackupError("preflight", "the game or Godot is running, close it first")
    if os.path.exists(os.path.join(cfg.src, ".git", "index.lock")):
        raise BackupError("preflight", ".git/index.lock exists (git is busy)")
    last = newest_zip(cfg.dest)
    if last and last[1] >= now.replace(second=0, microsecond=0):
        raise BackupError("preflight", "clock looks wrong: newest zip %s is not older than now" % last[0])
    need = (1.3 * last[2] if last else 2 * 1024 ** 3) + cfg.margin
    free = free_fn(cfg.dest)
    if free < need:
        raise BackupError("preflight", "not enough space on the backup drive: %d MB free, need %d MB" % (free // 2 ** 20, need // 2 ** 20))
    name = "DynastyALWL_ProjectBackup_%s.zip" % now.strftime("%Y-%m-%d_%H%M")
    if os.path.exists(os.path.join(cfg.dest, name)) or os.path.exists(os.path.join(cfg.dest, name + ".partial")):
        raise BackupError("preflight", "target name already exists: " + name)
    cfgfile = os.path.join(cfg.src, ".git", "config")
    if os.path.isfile(cfgfile):
        with open(cfgfile, encoding="utf-8", errors="replace") as f:
            if re.search(r"://[^/\s@]+@|ghp_|gho_|github_pat_", f.read()):
                log("WARN: .git/config seems to hold a credential, it would be inside the zip")
    return name, last


def clean_partials(dest, log):
    for n in os.listdir(dest):
        p = os.path.join(dest, n)
        if n.endswith(".zip.partial") and os.path.isfile(p) and time.time() - os.path.getmtime(p) > 86400:
            os.remove(p)
            log("removed stale partial: " + n)


def scan(cfg):
    files, excluded = [], {}
    for base, prefix in ((cfg.src, PROJECT_PREFIX), (cfg.saves, SAVES_PREFIX)):
        for root, dirs, names in os.walk(base):
            keep = []
            for d in dirs:
                if prefix == PROJECT_PREFIX and d in EXCLUDE_DIRS:
                    excluded[d] = excluded.get(d, 0) + 1
                else:
                    keep.append(d)
            dirs[:] = keep
            for n in names:
                if prefix == PROJECT_PREFIX and any(fnmatch.fnmatch(n, pat) for pat in EXCLUDE_FILES):
                    excluded[n] = excluded.get(n, 0) + 1
                    continue
                path = os.path.join(root, n)
                if not os.path.isfile(path) or os.path.islink(path):
                    continue
                files.append((path, prefix + os.path.relpath(path, base).replace(os.sep, "/"), os.path.getsize(path)))
    return files, excluded


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_zip(cfg, partial, files, excluded, now):
    manifest = {
        "script_version": VERSION, "created": now.isoformat(timespec="seconds"),
        "project_source": cfg.src, "saves_source": cfg.saves,
        "file_count": len(files), "total_bytes": sum(f[2] for f in files),
        "excluded": excluded,
        "sha256_project_godot": sha256_of(os.path.join(cfg.src, "project.godot")) if os.path.isfile(os.path.join(cfg.src, "project.godot")) else None,
        "sha256_git_head": sha256_of(os.path.join(cfg.src, ".git", "HEAD")) if os.path.isfile(os.path.join(cfg.src, ".git", "HEAD")) else None,
    }
    with zipfile.ZipFile(partial, "w", zipfile.ZIP_DEFLATED, allowZip64=True, compresslevel=6, strict_timestamps=False) as z:
        for path, arc, _ in files:
            kind = zipfile.ZIP_STORED if arc.startswith(PROJECT_PREFIX + ".git/objects/") else zipfile.ZIP_DEFLATED
            for attempt in range(3):
                try:
                    z.write(path, arc, compress_type=kind)
                    break
                except OSError as e:
                    if attempt == 2:
                        raise BackupError("zip", "cannot read %s after 3 tries: %s" % (path, e))
                    time.sleep(1)
        z.writestr("BACKUP_MANIFEST.json", json.dumps(manifest, indent=1))
    with open(partial, "rb+") as f:
        f.flush()
        os.fsync(f.fileno())
    return manifest


def verify(partial, manifest, last):
    with zipfile.ZipFile(partial) as z:
        bad = z.testzip()
        if bad:
            raise BackupError("verify", "CRC error in " + bad)
        infos = [i for i in z.infolist() if i.filename != "BACKUP_MANIFEST.json"]
        if len(infos) != manifest["file_count"] or sum(i.file_size for i in infos) != manifest["total_bytes"]:
            raise BackupError("verify", "zip holds %d files / %d bytes, scan said %d / %d (a file changed while zipping?)"
                              % (len(infos), sum(i.file_size for i in infos), manifest["file_count"], manifest["total_bytes"]))
        names = {i.filename for i in infos}
        for req in REQUIRED:
            if not (req in names or (req.endswith("/") and any(n.startswith(req) for n in names))):
                raise BackupError("verify", "required path missing in zip: " + req)
    size = os.path.getsize(partial)
    if last and not (0.5 * last[2] <= size <= 1.5 * last[2]):
        return "WARN: size %d MB is more than 50 percent away from the last zip (%d MB)" % (size // 2 ** 20, last[2] // 2 ** 20)
    return None


def restore_test(cfg, zippath, log):
    scratch = os.path.join(cfg.dest, "_restore_test")
    if os.path.exists(scratch):
        shutil.rmtree(scratch)
    try:
        os.makedirs(scratch)
        with zipfile.ZipFile(zippath) as z:
            z.extractall(scratch)
        proj = os.path.join(scratch, "DynastyALWL")
        for args in (["fsck", "--connectivity-only"], ["status", "--porcelain"]):
            r = subprocess.run(["git", "-C", proj] + args, capture_output=True, text=True, timeout=1800)
            if r.returncode != 0:
                raise BackupError("restore test", "git %s failed: %s" % (args[0], (r.stderr or r.stdout)[-200:]))
        with open(os.path.join(proj, "_addon_check.gd"), "w") as f:
            f.write('extends SceneTree\nfunc _init():\n\tvar ok = ClassDB.class_exists("VoxelTerrain") and (ClassDB.class_exists("WaterCore") or ClassDB.class_exists("WaterSimCore"))\n'
                    '\tprint("ADDON_OK" if ok else "ADDON_FAIL")\n\tquit(0 if ok else 1)\n')
        subprocess.run([cfg.godot, "--headless", "--path", proj, "--import"], capture_output=True, text=True, timeout=1800)
        r = subprocess.run([cfg.godot, "--headless", "--path", proj, "--script", "res://_addon_check.gd"], capture_output=True, text=True, timeout=600)
        if "ADDON_OK" not in r.stdout:
            raise BackupError("restore test", "voxel/water_core addons did not load in the restored copy")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    log("restore test OK (git fsck, git status, addons load)")


def keep_awake(on):
    try:
        ctypes.windll.kernel32.SetThreadExecutionState(0x80000001 if on else 0x80000000)
    except (AttributeError, OSError):
        pass


def run(cfg, now=None, game_running_fn=game_running, free_fn=lambda p: shutil.disk_usage(p).free):
    now = now or datetime.datetime.now()
    log = make_log(cfg.dest)
    partial = None
    keep_awake(True)
    try:
        if cfg.cull_only:
            n, alerts = do_cull(cfg.dest, now.date(), cfg.cull_live, cfg.max_moves, log)
            return "Cull %s: %d moves, %d alerts" % ("done" if cfg.cull_live else "dry-run", n, len(alerts))
        name, last = preflight(cfg, log, now, game_running_fn, free_fn)
        if cfg.preflight_only:
            return "Preflight OK: would write " + name
        clean_partials(cfg.dest, log)
        files, excluded = scan(cfg)
        log("scan: %d files, %d MB; excluded: %s" % (len(files), sum(f[2] for f in files) // 2 ** 20, json.dumps(excluded)))
        partial = os.path.join(cfg.dest, name + ".partial")
        manifest = write_zip(cfg, partial, files, excluded, now)
        warn = verify(partial, manifest, last)
        if warn:
            log(warn)
        final = os.path.join(cfg.dest, name)
        if os.path.exists(final):
            raise BackupError("rename", "target appeared meanwhile: " + name)
        os.replace(partial, final)
        partial = None
        size = os.path.getsize(final)
        with open(os.path.join(cfg.dest, "LAST_BACKUP_OK.txt"), "w") as f:
            f.write("%s\n" % name)
        with open(os.path.join(cfg.dest, "backup_status.json"), "w") as f:
            json.dump({"name": name, "bytes": size, "time": now.isoformat(timespec="seconds"), "files": len(files)}, f)
        log("zip written and verified: %s, %d MB" % (name, size // 2 ** 20))
        if cfg.no_restore_test:
            restore = "restore test SKIPPED"
            log(restore)
        else:
            restore_test(cfg, final, log)
            restore = "restore test OK"
        n, alerts = do_cull(cfg.dest, now.date(), cfg.cull_live, cfg.max_moves, log)
        return "Backup done: %s, %d MB, %s, culled %d%s%s" % (name, size // 2 ** 20, restore, n, "" if cfg.cull_live else " (dry-run)",
                                                          ", %d cull alerts" % len(alerts) if alerts else "")
    except BaseException:
        if partial and os.path.exists(partial):
            os.remove(partial)      # a failed run never leaves a half zip; older zips are untouched
        raise
    finally:
        keep_awake(False)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--saves", default=DEFAULT_SAVES)
    ap.add_argument("--dest", default=DEFAULT_DEST)
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--cull-live", action="store_true")
    ap.add_argument("--cull-only", action="store_true")
    ap.add_argument("--preflight", dest="preflight_only", action="store_true")
    ap.add_argument("--no-restore-test", action="store_true")
    ap.add_argument("--max-moves", type=int, default=MAX_MOVES)
    ap.add_argument("--margin-gb", type=float, default=FREE_MARGIN / 1024 ** 3)
    cfg = ap.parse_args(argv)
    cfg.margin = int(cfg.margin_gb * 1024 ** 3)
    try:
        print(run(cfg))
        return 0
    except BackupError as e:
        print("Backup FAILED: %s, %s" % (e.step, e.reason))
        return 1
    except Exception as e:      # never a silent crash
        print("Backup FAILED: unexpected, %r" % (e,))
        return 1


if __name__ == "__main__":
    sys.exit(main())
