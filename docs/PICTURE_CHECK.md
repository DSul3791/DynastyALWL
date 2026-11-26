# Picture checker and the picture sweep

Dave, 26 Nov 2026, project chat: "ok make it", after the plan to use his API credits (about $158, expiring within weeks) for one big
sweep: the lane takes in-game pictures of everything, the Claude API looks at them, and the result is one list of what looks wrong.
The credits are his: the checker never spends past its cap, and it keeps a running total.

## What runs where
- Pictures: only on Dave's PC lane, from `C:\DynastyLane\clone`, with the in-game picture tools (`creature_check.gd`, `shot_held.gd`,
  `body_pose_shot.gd`, `look_rig.sh`). Godot never runs in the cloud. `tools/picture_sweep.py` runs them one at a time in the
  foreground, each with a time limit, and stops the whole process tree it started (`taskkill /F /T`: look_rig's server and client
  too) when the limit passes, when the CANCEL file appears, or on Ctrl-C. It runs look_rig with Git bash, never WSL's bash.
- Looking: `tools/picture_check.py` sends the pictures to the Claude API (model `claude-opus-5-5`, low effort). The pictures of one
  folder are the views of one subject and go in one request (at most 8 a request), so it judges a subject across its views
  and writes `picture_check.md` (the list, most serious first) and `picture_check.json`. Python standard library only: nothing to
  install on Dave's PC.
- Both stop when the lane's `C:\DynastyLane\logs\queue\CANCEL` file exists (the checker between pictures, the sweep within a second). Bug-fix tests go first in the lane queue;
  the sweep runs in slices (`--max-jobs`, `--time-limit`) and picks up where it stopped, skipping jobs whose pictures are there.

## The key (Dave, once)
The key lives only in `C:\DynastyLane\picture_check_key.txt`, outside the clone, so it can never be committed. No key goes in the
repo, chat, logs or reports; the checker reads the file and sends it only in the request header. Dave runs this once in PowerShell
and pastes the key when asked (it shows on his screen while he pastes; nothing else keeps it):

```powershell
Read-Host "Paste the API key" | Set-Content -NoNewline -Encoding ascii C:\DynastyLane\picture_check_key.txt
```

Second guard, set before the first run: a spend limit on the key's workspace in the Claude Console (for example $150), so even
a bug here or a price change could not pass it.

## Spending
- Cap: $150 by default (below the $158 Dave has), kept in `C:\DynastyLane\picture_check\spent.json`; `--cap USD` changes it.
- Before each request the checker reserves its worst case (all input as a cache write, the whole 4000-token answer as output, about
  $0.10); the answer's real usage replaces the reservation. A request whose worst case would pass the cap is not sent. A run cut off
  mid-request keeps its reservation counted, so the total can only read high, never low.
- One check runs at a time: a second one refuses to start while `C:\DynastyLane\picture_check\lock` exists (delete it by hand only
  after a cut-off run, when no check runs). If `spent.json` is lost while answers are stored, the checker refuses to run until
  `--cap` is given with what is really left.
- Network errors and gateway timeouts are not retried (they may have been billed): each is counted at its worst case.
- The prices in the script are the published `claude-opus-5-5` rates of 26 Nov 2026. **The first run ever sends one request only**
  (the checker enforces it while the ledger has no request); compare the dollar figure it prints with the Console's usage before
  any bigger run.
- Answers are stored by the pictures' content and their about text (`answers.json` there): a subject checked once is never paid for
  again (`--recheck` to ask anew).
- Expected cost: a 1920x1080 picture is about 2,800 input tokens. One subject with four views is about 11,000 input tokens and one
  answer, roughly 6 cents (the first one-picture run cost $0.028). The whole sweep (about 280 subjects) is roughly $15 to $25.
  `--dry-run` prints the count and the worst case without sending anything.

## Commands (lane, Git bash, from `C:/DynastyLane/clone`)
```bash
python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep --list                      # jobs left
python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep --groups animals,young --time-limit 3600
python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep --dry-run
python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep --max-requests 1   # first ever: compare with the Console
python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep --time-limit 3600
python tools/picture_check.py C:/DynastyLane/logs/<job>/shots --about "a deer walking on grass"   # any test's pictures
```
Groups: `animals` and `young` (every species, every role, 46 strips each), `held` (128 tools and weapons, 4 angles: about 85 by
`shot_held.gd` in seconds, the rest, which it refuses (bows, spears, nets, shields, torches, lanterns...), by `look_rig.sh --item`
in the world, minutes each), `worn` (79 worn items, idle front and side, walk and run), `pieces` (every structure in the world, 8 a
run), `tiers` (the spawn on Low and High, four directions). Each picture folder has an `about.txt` saying what it should show; the
checker passes it on. A job that finished with its pictures is skipped (one cut off part way is taken again): delete its folder to take its pictures
again (after a look change).
The animal strips hold up to a dozen poses side by side and reach the API scaled to 2576 px wide, so small gaps under feet may come
back "unsure"; check one strip's answer before the whole group.

## What it reports, and what not
A subject is called wrong only when the bug shows in more than one view, or is unmistakable in one; a doubt one view alone
shows is listed as unsure, for a person to look at. The checker is told what the tester does on purpose: stills freeze a pose
mid-clip, a long item pointing at the camera looks short, the game cuts the grass short within 1.4 m of the player so the feet
show (`src/client/grass_view.gd` `PLAYER_CLEAR_M`: the flat patch round the feet in world pictures is the game, not the rig),
and the offline tools' plain sky, grid floor and bright sun.

Floating, sunk, clipping, skin through clothes, held wrong, broken poses, missing textures, broken meshes, wrong scale, broken
lighting. Never art style, art quality or "looks AI-made" (project rule), and character creation is not swept. Its findings are
leads, not verdicts: a person looks at each picture before an entry goes in `BugsList_Current.md` under the normal rules.

Self-test (cloud or PC, fake API, no key, no Godot): `python3 tools/test_picture_check.py`.
