# Picture checker and the picture sweep

Dave, 26 Nov 2026, project chat: "ok make it", after the plan to use his API credits (about $158, expiring within weeks) for one big
sweep: the lane takes in-game pictures of everything, the Claude API looks at them, and the result is one list of what looks wrong.
The credits are his: the checker never spends past its cap, and it keeps a running total.

## What runs where
- Pictures: only on Dave's PC lane, from `C:\DynastyLane\clone`, with the in-game picture tools (`creature_check.gd`, `shot_held.gd`,
  `body_pose_shot.gd`, `look_rig.sh`). Godot never runs in the cloud. `tools/picture_sweep.py` runs them one at a time in the
  foreground, each with a time limit, and stops the run it started when the limit passes.
- Looking: `tools/picture_check.py` sends each picture to the Claude API (model `claude-opus-5-5`, low effort, one picture a request)
  and writes `picture_check.md` (the list, most serious first) and `picture_check.json`. Python standard library only: nothing to
  install on Dave's PC.
- Both stop between steps when the lane's `C:\DynastyLane\logs\queue\CANCEL` file exists. Bug-fix tests go first in the lane queue;
  the sweep runs in slices (`--max-jobs`, `--time-limit`) and picks up where it stopped, skipping jobs whose pictures are there.

## The key (Dave, once)
The key lives only in `C:\DynastyLane\picture_check_key.txt`, outside the clone, so it can never be committed. No key goes in the
repo, chat, logs or reports; the checker reads the file and sends it only in the request header. Dave runs this once in PowerShell
and pastes the key when asked:

```powershell
Read-Host "Paste the API key" | Set-Content -NoNewline -Encoding ascii C:\DynastyLane\picture_check_key.txt
```

Optional extra guard: a monthly spend limit on the key in the Claude Console, so even a bug here could not pass it.

## Spending
- Cap: $150 by default (below the $158 Dave has), kept in `C:\DynastyLane\picture_check\spent.json`; `--cap USD` changes it.
- Before each request the checker reserves its worst case (all input as a cache write, the whole 4000-token answer as output, about
  $0.10); the answer's real usage replaces the reservation. A request whose worst case would pass the cap is not sent. A run cut off
  mid-request keeps its reservation counted, so the total can only read high, never low.
- Answers are stored by picture content (`answers.json` there): a picture checked once is never paid for again (`--recheck` to ask anew).
- Expected cost: a 1920x1080 picture is about 2,800 input tokens and a few hundred output tokens, roughly 2 to 3 cents. The whole sweep
  (about 1,000 pictures) is roughly $20 to $30. `--dry-run` prints the count and the worst case without sending anything.

## Commands (lane, Git bash, from `C:/DynastyLane/clone`)
```bash
python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep --list                      # jobs left
python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep --groups animals,young --time-limit 3600
python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep --dry-run
python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep --time-limit 3600
python tools/picture_check.py C:/DynastyLane/logs/<job>/shots --about "a deer walking on grass"   # any test's pictures
```
Groups: `animals` and `young` (every species, every role, 46 strips each), `held` (128 tools and weapons, 4 angles), `worn` (79 worn
items, idle front and side, walk and run), `pieces` (every structure in the world, 8 a run), `tiers` (the spawn on Low and High, four
directions). Each picture folder has an `about.txt` saying what it should show; the checker passes it on.

## What it reports, and what not
Floating, sunk, clipping, skin through clothes, held wrong, broken poses, missing textures, broken meshes, wrong scale, broken
lighting. Never art style, art quality or "looks AI-made" (project rule), and character creation is not swept. Its findings are
leads, not verdicts: a person looks at each picture before an entry goes in `BugsList_Current.md` under the normal rules.

Self-test (cloud or PC, fake API, no key, no Godot): `python3 tools/test_picture_check.py`.
