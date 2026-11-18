# Who is an admin on a server

Server/client split step A5 (18 Nov 2026; plan: Library `server-client-split/PLAN.md`). Test players join a server and must be ordinary players; Dave's own local Play keeps every admin tool.

## The rule in code

- **The server decides.** `src/stream/server_admin.gd` holds the admin keys. They are read from `data/admin.json` (gitignored) and `<store>/admin.json`, shape `{"keys": ["<player key>"]}` (`data/admin.example.json`).
- **The check is off in local play,** so everybody is an admin, as before. It is on when `data/items/admin_setting.json` `check_admin` is true, or when the server is started with `--check-admin`. A server for other players is started with `--check-admin`; the repo setting stays false so Dave's editor Play is unchanged.
- **`--check-admin` beats `--open-admin`** (a headless-test switch), so a test switch can't open a server for other players.
- **The server logs one line at start:** `server: admin check on: N admin keys` (never the keys), or that nobody is an admin when no `admin.json` lists one.
- **Protocol 132:** after each hello the server sends `admin_status(on)`. When it is false, the client hides Esc > Admin (on the main and settings pages), switches flying off, turns Admin mode off, and ignores the two admin keys that act only on the client (fly, and go to the nearest NPC).

A player key is per character: `CharacterKeys.key_for(character id, machine key)`. Esc > Admin > "Show my player key" copies it. Dave reads his in local Play with the character he will use on the server, and that key goes into the server's `<store>/admin.json`.

## Audit: every admin or cheat path (dev `6dedf7fe`)

| Path | Who may, with the check on | Where checked |
|---|---|---|
| Give items (`ACT_ADMIN_GIVE`; starter items key, Admin build list) | admins | server_items `action` |
| Admin mode, free crafting (`ACT_ADMIN_MODE`, `free_craft_for`) | admins | server_items |
| Set energy (`ACT_ADMIN_ENERGY`) | admins | server_items |
| Play as a new player (`ACT_NEW_PLAYER`) | admins | server_items |
| Showroom fill or clear (`ACT_SHOWROOM`) | admins | server_items |
| Clear dropped items (`ACT_CLEAR_DROPS`) | admins | server_items |
| Admin spyglass (`ACT_SPYGLASS` a = 1); a spyglass item (a = 2) is for everyone | admins | server_items |
| Dump water, land types (`ACT_DUMP_WATER`, `ACT_LAND_TYPES`) | admins | server_items |
| Reset terrain edits, reset world (`ACT_RESET_EDITS`, `ACT_RESET_WORLD`) | admins | server_items |
| Admin dig (`dig`, Ctrl+Shift+X) | admins | terrain_server `_on_dig_requested` |
| Place markers, NPC homes, rabbits (`admin_place`) | admins | terrain_server `_on_admin_place` |
| Tunnel collapse switch (`tunnel_setting`) | admins | terrain_server `_on_tunnel_setting` |
| **Spring flow up/down (`step_water_rate`)** | **admins (new: anyone could before)** | terrain_server `_on_water_rate_requested` |
| **Ground report "Dump ground here" (`request_dump`)** | **admins (new: anyone could before)** | terrain_server `_on_dump_requested` |
| Fly (Ctrl+Shift+G), go to the nearest NPC (Ctrl+Shift+N), Go to spawn and "Day, sunny, no fog" (Esc > Admin) | admins, on the client only (below) | terrain_client, game_menu |
| Quality, debug details, HUD text, sound panel, water hide/colour, jitter test, GPU probe | everybody: they change only the player's own picture | none needed |

## Known limits (not fixed here)

- **The server trusts the position a client reports.** Fly, go to NPC and go to spawn move the player on the client only; the server has no movement check. The client now refuses them for non-admins, but a changed client could still fly or jump. A movement check is a design decision for Dave (not built).
- **A player key is a bearer secret,** sent in the clear at each hello (ENet is not encrypted). Anyone who learns Dave's key can be admin. This is today's machine-key sign-in, kept by choice (no new sign-in scheme in this step). Dave should not show "Show my player key" on stream or in screenshots.

## Assumed on Dave's behalf, for his review (provisional)

| # | Assumption | Status |
|---|---|---|
| AC-1 | Only Dave's player key is an admin on the test server (its `<store>/admin.json` lists one key). | Coordinator's pick, provisional |
| AC-2 | Testers sign in with today's machine key; no passwords or accounts. | Coordinator's pick, provisional |
| AC-3 | A server for other players is started with `--check-admin`; `check_admin` in the repo stays false so local Play is unchanged. | Assumed, provisional |
| AC-4 | Non-admins get no Esc > Admin page at all (the "Show my player key" button is in it; Dave reads his key in local Play). | Assumed, provisional |
