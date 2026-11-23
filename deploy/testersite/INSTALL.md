# The tester site: front page, bug and idea forms, high scores

Dave asked on 23 Nov 2026 for his own tester pages on his web server, https://hannibalshouse.duckdns.org/ (Caddy in Docker on
dell-gameserver-01, container `game-web`, login for four testers over the whole site). The front page has three boxes: **Download
latest** (with the build number), **Submit a bug** and **Suggest an idea**, and a **high-score table** under them: every tester, bugs
reported, ideas, total score, sortable by any column. Testers need no GitHub account: the site files each report as an issue on
[DynastyALWL-QA](https://github.com/DSul3791/DynastyALWL-QA/issues) under their login name. Nothing is reported from inside the game.

**Status: tested in the cloud only** (a copy of the server's set-up with Caddy, the login and a fake GitHub). Not yet run on Dave's server.

## How it works

| Part | Where | What it does |
|---|---|---|
| `site/index.html`, `bug.html`, `idea.html`, `css/`, `js/` | `/data/game-web/site/` | The pages. The build number comes from `/latest.json` (written by `tools/make_testplayers_site.ps1`). |
| `service/reports.py` | `/data/game-web/reports/`, container `dynasty-reports` | Takes a form, saves it, files the GitHub issue, keeps the counts. Python's standard library only, in the stock `python:3.12-alpine` image. |
| one `reverse_proxy` block | `/data/game-web/config/Caddyfile` | Sends `/api/...` to the service with the tester's login name. |

- **Who sent it:** Caddy checks the login first, then sends the login name to the service in its own header, replacing any header of
  that name the browser sent. The service has no port on the server; only Caddy can reach it. So nobody can post as somebody else.
- **Never lost:** every report is saved on the server before it goes to GitHub. If GitHub cannot be reached (or the token is wrong),
  the report waits and is sent every two minutes until it gets through. It counts on the high-score table straight away.
- **The forms** are as short as possible (Dave: "ridiculously simple"): bug = Build (filled in), Short title, What happened, Attach files; idea = Build, Short title, Your idea. **The issue** uses the GitHub forms' headings for those boxes, "Sent from the tester site by **name**", and the
  labels `bug` or `idea` plus `tester-site`. A game log or crash report is posted as comments under the issue (the last 360,000
  characters, where the crash is). Screenshots stay on the server and the issue links to them (log in to see them).
- **Limits:** 20 reports per tester per hour, 30 MB per report, 4 pictures of 8 MB, 20,000 characters per box. An `@name` in a
  report does not notify anyone on GitHub. Forms only send from the site's own pages.
- **Score:** total = bugs + ideas, one point each. Default order: highest total first; equal totals (everyone at zero, too)
  alphabetical by name. All the testers in the Caddyfile's login list show, even at zero.
- **Service down:** the front page still shows the boxes and the download; the table says the scores are resting.

## Install (Dave, about 10 minutes, once)

### 1. Make the GitHub token (in a browser)

1. Open https://github.com/settings/personal-access-tokens/new (GitHub, Settings, Developer settings, Fine-grained tokens, Generate new token).
2. **Token name:** `Dynasty tester site`. **Expiration:** the longest it offers (a year, or "No expiration" if your account allows it).
3. **Repository access:** *Only select repositories*, then pick **DSul3791/DynastyALWL-QA** only.
4. **Permissions:** *Repository permissions*, **Issues: Read and write**. Leave everything else as it is (Metadata: Read-only is added by itself).
5. **Generate token** and copy it (it starts with `github_pat_`). Keep the page open until step 2 is done. Do not paste it anywhere else.

### 2. Install on the server (one paste)

Log in to the server (`ssh dave@dell-gameserver-01` from PowerShell) and paste:

```
sudo mkdir -p /data/game-web/reports && cd /data/game-web/reports && sudo curl -fsSLO https://raw.githubusercontent.com/DSul3791/DynastyALWL/dev/deploy/testersite/service/install.sh && sudo bash install.sh
```

When it asks, paste the token and press Enter (nothing shows while you paste). It prints seven steps and ends with **DONE**.
If it says **STOPPED**, it tells you why, and anything it changed in Caddy is put back as it was. Send the message to Claude.

What it changes: it adds `/data/game-web/reports/` (the service, the token readable only by root, the reports), copies the pages
into the site folder (the old `index.html` is kept as `index.before-reports.html`), and adds one block to the Caddyfile (the old one is
kept as `Caddyfile.before-reports`). The login, the HTTPS certificate and `compose.yaml` are not touched.

### 3. Check (in a browser)

1. Open https://hannibalshouse.duckdns.org/ and log in. The three boxes show the build number, and the high-score table shows all four testers at 0.
2. Press **Submit a bug**, fill in a test bug and send it. It should answer "It is on GitHub as issue #N".
3. Open the link: the issue says it was sent by your login name. Close it on GitHub, then take it off the table:
   `sudo docker exec dynasty-reports python /app/reports.py list`, then `sudo docker exec dynasty-reports python /app/reports.py remove <id>`.

## Later

- **Update the pages or the service:** run the same paste again. It keeps the token, the reports and the Caddy change.
- **A new build:** nothing to do here. The packaging script's `latest.json` gives the new number.
- **New token** (when the old one runs out; GitHub emails you first): `sudo rm /data/game-web/reports/github_token`, then the same paste.
  Reports sent meanwhile wait and go through once the new token is in.
- **A new tester login:** add it to the Caddyfile as usual, then run the same paste so the table lists them at zero.
- **See what happened:** `sudo docker logs --tail 50 dynasty-reports` and `sudo docker exec dynasty-reports python /app/reports.py list`.
- **Stop it:** `cd /data/game-web/reports && sudo docker compose down`. The pages then say the scores are resting; reports cannot be sent.
- **Back-up:** the reports are in `/data/game-web/reports/data/reports.db`; every one is also on GitHub.

## By hand (only if install.sh stops at step 6)

Inside the `hannibalshouse.duckdns.org { ... }` block of `/data/game-web/config/Caddyfile`, just above `file_server browse`:

```
	reverse_proxy /api/* dynasty-reports:8080 {
		header_up X-Dynasty-User {http.auth.user.id}
		header_up -Authorization
	}
```

Then `sudo docker exec game-web caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` and the same with `reload`.

## For developers

- `python3 tools/test_tester_site.py` checks the service against a fake GitHub (no network, no Docker).
- `install.sh` takes `SOURCE=<a local deploy/testersite folder>` instead of downloading, `BRANCH=<branch>` to download another
  branch, and keeps any extra line in `.env` (the cloud test sets `GITHUB_API` to a fake GitHub container there).
- The front page reads `/latest.json` at load, so it needs no filling in per build. If Caddy's `templates` is on for `/`
  (deploy/testplayers/SERVER.md step 3) the login name is filled in by Caddy; otherwise the page asks `/api/me`.
