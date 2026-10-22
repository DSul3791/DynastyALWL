# Restore procedure (for Dave; nobody has to be online). Written 2026-10-22 by the Guru. Test it once for real at the first backup run, then once a month.
Backups are in `E:\Software\godotDev\DynastyALWL_ProjectBackups\` (newest nightlies there, old weeks in `weekly\`, recently culled in `_trash\` for 7 days).

## Restore the whole project (code, tiles, docs)
1. Close the game, Godot and GitHub Desktop.
2. Right-click the zip you want (usually the newest, check the date in the name) > Extract All > a NEW folder such as `C:\GodotProjects\DynastyALWL_restored`. Never extract over your working folder.
3. Open the new folder in GitHub Desktop (File > Add local repository). Check the current branch is claude/generator-v2 and the latest commit looks right. Open it in Godot (Import > project.godot) and press F6 to be sure it runs.
4. If happy, keep your old folder renamed (`DynastyALWL_old`) and use the restored one.

## Restore only the world saves
1. Close the game completely.
2. In the zip, the saves are in the folder named `server_data` (the manifest file `BACKUP_MANIFEST.json` says its original path, normally `%APPDATA%\Godot\app_userdata\Dynasty a life well lived\server_data`).
3. Rename the current `server_data` to `server_data_before_restore`, then extract the zip's `server_data` to that place.
4. Start the game. If something is wrong, put the renamed folder back.

## Restore one file
Open the zip in Explorer, copy the single file out to the right place. Do not drag the whole zip contents over a working folder.

## If the newest zip will not open
Use the one before it (or ask MikeW to run the restore test on it). The logs `backup_log.txt` and `backup_status.json` in the backup folder say which nights passed their restore test.

## Monthly drill (5 minutes)
Do "Restore the whole project" into a scratch folder, open it, delete it. Tell the coordinator "drill done" or what went wrong.
