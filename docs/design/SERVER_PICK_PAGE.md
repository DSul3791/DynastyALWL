# Server pick page (client)

**Status:** APPROVED by Dave, 19 Nov 2026 ("I like the page design so I approve it"). Being built; nobody has played or seen it in the game yet. Choices 1 and 2 (end of this file) were settled by Dave on 21 Nov 2026 as built. Revised the same day around Dave's own layout. Mock-up: `SERVER_PICK_PAGE_mockup.png` beside this file (a drawing, not a screenshot).

**Dave's words (19 Nov 2026, project chat):** "setup our client game page where you pick what server you want to connect too. this will take some design because I feel most developers don't give this step the love it deserves. The client can connect to a preset official server or to a direct connect. every direct connect should be saved in a list for quick picking next time. they should be allowed to use ip addresses or redirects like hannibalshouse.duckdns.org"

Part of the server/client split (`/mnt/project-files/server-client-split/PLAN.md`). It replaces the one-box join page from step A2 (`src/client/join_page.gd`, PR #1275).

## What exists today (dev e606b8ac)

- Only a client-only build (export feature `client_only`, or `--client-only`) shows a join page. Editor and PC Play keep starting their own local server (`scenes/launcher.gd` `_host_and_play`) and are not changed by this design.
- `src/client/join_page.gd`: one address box (last typed, else `client_config.json` shipped beside the game), Join and Quit. It remembers one address in `user://join_address.cfg`.
- `src/client/join_address.gd`: parses `host` or `host:port`, default port 24600; IPv6 refused (shortcut).
- `scenes/terrain_client/terrain_client.gd`: failures appear on the connect window after Join (no address, cannot open, no answer in 30 s, not welcomed, build refused "Update required"). Nothing is known about a server before joining.
- Order of pages: title, character select (characters are local), then the join page.

## The pages the client needs (front-end flow)

Dave, 19 Nov 2026: "all games have a welcome to the game page with custom graphics but what pages do we really need. Like we I love the continue button and I think that should immediately go to the connection page that already has your last server lined up to join. Should it also have your last character on that server lined up to start? or should it just go to that server with that character without asking."

**Today (dev e606b8ac):** Title page (`scenes/title`, Dave's paintings: New Game, Continue, Settings, Exit; Continue is dimmed until this computer has a character). New Game goes to the creator; Continue goes to character select (`scenes/character_select`, characters kept on this computer only, `character_store.gd`). After a character is chosen a client-only build shows the one-box join page; editor and PC Play start a local server instead.

**Proposed: four pages, nothing else.**
1. **Welcome** (the existing painted title page, kept): Continue, Play (was New Game), Settings, Exit. Continue shows only once this computer has joined a server with a character.
2. **Servers** (this page): official first, then every server added, with Add new server and Join server.
3. **Characters** (the existing select page and creator): reached after a server is chosen, titled "Playing on <server>", and lines up the character last played on that server. Characters stay on this computer for now (they are not yet saved on servers); the page only remembers, per server, which one was used there. When characters move to the server later, this page lists that server's characters instead and nothing else in the flow changes.
4. **Settings** (the existing title settings).

Play goes Servers, then Characters, then the game. New players with no character land on the creator from the Characters page, as today.

**Continue (Dave's choice 4 below).** Pick: Continue goes straight into the game with the last server and the character last played there. The connect window says "Joining Hannibal's House as Aldric" with a Cancel button (back to the Servers page with that server lined up). If that cannot work (server offline, other build, full, the character was deleted) it does not fail on a red screen: it opens the Servers page with that server chosen and the reason on its row. This is one click for the common case and never a dead end.

## What other games do well (and badly)

- **Minecraft multiplayer list:** every saved server is asked for its status as the page opens: name, message, players online, ping bars, and a red "outdated" mark when versions differ, all before you press Join. Separate "Direct Connect" (one-off, not saved) and "Add Server" (saved). Best idea to take: live status on every row. Weak spot Dave already spotted: a direct connect is forgotten.
- **Steam server browser (Source games, Rust, ARK):** a History tab fills itself with every server joined, with "last played", next to Favorites. Best idea: history that saves itself. Weak spot: tabs and columns made for thousands of servers, too heavy for a handful.
- **Satisfactory server manager:** shows each saved server's state and game version, and explains a version mismatch in words. Best idea: say which side must update.
- **Valheim / Factorio:** "Join by IP" with a recent list; Factorio keeps a history of typed addresses. Weak spot: errors are a code or "connection failed" with no hint of why.
- Common gaps to avoid: a frozen window while a name is looked up, a long silent timeout, "connection failed" without saying whether the name, the port or the version was wrong, and a list that saves the IP a dynamic name pointed to on the day it was typed.

## The page (Dave's layout, 19 Nov 2026)

Dave, 19 Nov 2026: "if you select play it needs to take you to our server selection page where the top choice is the offical server then all your previously directly connected servers. those servers should show up on the list even if they don't ping just incase they are down for some reason. they could be listed in red. working servers would look normal white or grey text. they should all show server name, ping, status. or something like that and at the bottom of the page could be a button just say add new server, join server(which would join the picked server) you could also join a server by double clicking it on the list."

One list, full width (see the mock-up):
1. **The official server, always first** (set apart with a gold edge). Its address is a release setting (`client_config.json` `"official"`, written by the release script), never typed by the player, and it cannot be removed. A build with no official address yet does not show the row.
2. **Every server this player has added, below it**, last played first. A saved server **never leaves the list because it does not answer**.

Columns: **Server name**, **Players** (2 / 32), **Ping** (ms and bars), **Status** in words, **Last played**. The address shows small under the name.

Colours: a working server is in normal white/grey text. A server that does not answer (offline, name not found) is in **red**, still on the list and still joinable (it may come back). A server that answers but cannot be joined right now (other build, full) is in **amber**, with the reason in the Status column.

Bottom row of buttons: **Back** (to the Welcome page), **Refresh** (asks every server again), **Remove**, **Rename**, **Add new server**, and the big **Join server** (joins the chosen row). **Double-click** a row joins it; Enter joins the chosen row. Opening the page chooses the server last played, so Join or Enter gets back in with one key.

**Add new server** opens a small box: Address (IP or a name such as hannibalshouse.duckdns.org, `:port` only if not 24600) and an optional Name. Buttons: **Add** (saves it to the list and checks it) and Cancel. A bad address is named in red in the box and nothing is saved. The new row is chosen at once, so Join is the next click. Without a name the row uses the name the server reports, else the address.

**Rename** changes only the name shown on this computer. **Remove** takes the row off at once with an "Undo" bar for 8 seconds instead of a confirm box. The official row has neither.

Join goes on to the Characters page with this server's last character lined up.

## Status of each server

As the page opens, and on Refresh, the game asks every listed server for its status, all at once, in the background; nothing on the page waits. Each row shows one of:

| Row shows | Meaning | Words on the row |
|---|---|---|
| grey "Checking…" | still asking | Checking… |
| white/grey text | answered, same build | Online · 2 of 32 playing · 63 ms |
| amber text | answered, other build | Needs update: server is build 8020, you have 8012 (or: "Server is older (8005): its owner must update it") |
| amber text | answered, full | Full: 32 of 32 playing |
| red text | no answer in 5 s | Offline · last answered 3 days ago |
| red text | the name does not exist | Name not found: check the spelling |
| red text | the address cannot be used | the parse error in plain words (as `join_address.gd` today) |

Join stays possible on a red (offline) row: the server may have just come up. On a build mismatch Join is replaced by the update advice; when the client is the older side and the updater (plan A6) exists, the button becomes "Update the game".

**How the status is asked (server change, small):** a new request on the existing TCP block line (port + 1, `src/stream/block_link_server.gd`): a client that sends a STATUS frame instead of HELLO gets one small reply and the line closes: server name, build, protocol, players online, max players, the short message, and player names if the server shares them. Ping is the time to that reply. No ENet join, no character, nothing logged as a join. The server name and message are two lines in the server's store (`<store>/server.json`, set by whoever runs it). An old server with no STATUS answers nothing useful and the row says "Online (no details)" when the TCP line opened, else Offline.

## Server passwords (Dave, 19 Nov 2026)

Dave: "servers need the ability to also have a password. so once you pick your server and try to connect we will have a popup that asks for the password. you get 3 tries if you get it wrong. then you get a message that says. you got it wrong 3 times. check your caps lock, and take a minute to recompose. then it should set you back at the pick a server page."

**Player side**
- A server with a password shows a **padlock** on its row (from the status reply), so the player knows before pressing Join.
- Join on a locked server opens a small popup: "Hannibal's House needs a password", a hidden-text box with a show/hide eye, a **Caps Lock is on** warning when it is, OK and Cancel. Enter is OK.
- Wrong: the popup stays, the box empties, and it says "Wrong password. 2 tries left." then "1 try left."
- Third wrong: the popup closes and a message says **"You got it wrong 3 times. Check your Caps Lock, and take a minute to recompose."** with OK, which goes back to the server page with that server still chosen. The player may try again from there.
- Cancel goes back to the server page at any time.
- Continue on a locked server asks for the password the same way (unless it is remembered, choice 3).

**Server side**
- Optional setting: no password means an open server, exactly as today. The setting lives in the server's store (`<store>/server.json`, beside the name and message) and can also be given to the Docker container as an environment variable, so it never has to sit in a file inside the image. The exact setting name is agreed with the Docker/server work before it is built.
- The server keeps only a salted hash of the password, never the password itself. The password never crosses the network: at join the server sends its salt and a fresh one-time number; the client sends back a proof made from the password and that number. The server checks the proof. A copied proof is useless for the next join.
- The check is on the server, before the player gets anything of the world. The client's three tries are the page's rule; the server has its own guard against a script guessing: after 5 wrong proofs from one address in a minute it refuses that address for a minute.
- The admin key check is separate and unchanged: the password lets a player in, it never makes anyone an admin.
- Protocol bump (with the status request).

## Joining and the failures after Join

Join opens the existing connect window (`connect_window.gd`), which already names each step. Changes:
- Its Quit button becomes **Back to servers** (keeps the game open, back to this page with that row chosen). Quit stays as a second button.
- The words name the cause and the fix:
  - name lookup failed: "No server is called hannibalshouse.duckdns.org. Check the spelling; if it worked before, the name's owner may have let it lapse."
  - no answer: "Nothing answered at hannibalshouse.duckdns.org (port 24600). The server may be off, or its router is not forwarding UDP 24600 and TCP 24601."
  - build refused (A1): as today, plus which side must update.
  - full: "The server is full (32 of 32). Try again later."

## Names, ports and redirects

- The list stores the address **as typed** (the name), never the IP it pointed to. A dynamic-DNS name such as duckdns is looked up fresh every time the page asks for status and every time it joins, so a home server whose IP changes keeps working.
- The lookup runs in the background (Godot `IP.resolve_hostname_queue_item`), never freezing the page. The resolved IP shows only in the hover note, for helping a friend set up.
- Default port 24600 is never shown in the list; `:port` is kept only when the player typed another port. The block line is always port + 1 and is never asked for.
- The same server typed twice (same name or IP, same port, any case, with or without `:24600`) updates the one row, never a duplicate.
- `http://`, `https://` and a trailing `/` pasted from a browser are stripped. IPv6 stays refused for now (existing shortcut), with words saying so.

## What is remembered, and where

- `user://servers.json` on the player's computer (for Windows: `%APPDATA%\Godot\app_userdata\Dynasty a life well lived\`). One list per Windows user. Per row: address as typed, the name the player gave it (empty means "use the server's own name"), the server's last-known name, first joined, last played, last answered, last build seen. A remembered server password only as its salted hash (choice 3), and no character data except which character was last played on each server.
- The old single address in `user://join_address.cfg` is read once and becomes the first row, so a tester who already typed an address keeps it.
- The selected row is remembered: next launch the page opens with the server last played already chosen, so Enter or Join gets back in with one key.
- Remove takes the row off at once, with an "Undo" bar for 8 seconds instead of a confirm box.
- Nothing is sent anywhere except the status request to the servers in the list.

## What stays the same

- Editor and PC Play (Dave's own work): unchanged, still a local server, no page.
- `--server=` on the command line and `--test` still go straight to the game.
- After a death the game rejoins the same server as the same character at once, as today (no pages).
- No bug reporting in the client (Dave, 18 Nov).

## Build plan (after approval)

1. `src/client/server_list.gd` + test: parse and normalise an address, de-duplicate, save/load `servers.json`, move the old `join_address.cfg`. No UI. (Can be prepared before approval: it only follows Dave's stated requirements.)
2. Status request and password: STATUS frame on the block line (with "locked"), the password check at join (salt, one-time number, proof), the guard against guessing, the setting in `server.json` and the container, `<store>/server.json` name and message, client query with lookup in the background and a 5 s limit + tests. Protocol bump.
3. The page itself (replaces `join_page.gd`), the connect window's Back to servers and its new words. One client smoke against a separate server on Lane A.
4. The flow: Welcome Play/Continue, Servers before Characters, per-server last character, Continue straight in with Cancel and the fall-back to the Servers page.
Each is one reviewed PR to dev with the selector's tests on the exact head.

## For Dave: the choices left to him

Settled by Dave (19 Nov): the game remembers a correct password (choice 3); passwords with a popup, 3 tries, then the caps-lock message and back to this page; Play opens this page; official first, then every added server; down servers stay, in red; name, ping and status on each row; Add new server and Join server buttons; double-click joins.

1. **Continue.** SETTLED (Dave 21 Nov 2026, "yes continue goes straight in with the last server and character and it remembers the password"): straight into the last server as the character last played there, with Cancel on the joining screen, and back to this page with the reason on the row if it cannot join. Other ways: Continue opens this page with the last server chosen (one more click), or opens the Characters page for the last server.
2. **Player names before joining.** SETTLED (Dave 21 Nov 2026, "yes each row can show server ip, name, player count, ping and status online or not"): the count only, no names. Under the name each row shows its address, and for a name such as a duckdns one also the IP it points to now.
3. **Remember a password.** SETTLED (Dave 19 Nov, "yes it should"): a "Remember on this computer" tick in the popup, on by default. What is remembered is the salted hash, never the typed password, kept in `servers.json`; Remove forgets it, and if the server's password changes the popup simply asks again. Someone who copied that file could join that one server, but never learns the password, so it is useless anywhere else. Other way: always ask.

Assumed meanwhile (provisional, can change, for Dave's review):
- The painted title button still reads "New Game" (it is part of the painting); in a client-only build it opens this page, i.e. it is Play. Repainting it to say Play is Dave's call.
- The official server shows as "Dynasty Official"-style only once the release setting (`client_config.json` "official") names an address; there is no crest picture yet, only the gold edge.
- The server's short message and its IP show when a row is hovered.
- Back to servers (from the joining screen or the password popup) starts the game again on this page: the cleanest way out of a half-made join.
- To see the page in the editor: run with the user argument `--client-only`.
