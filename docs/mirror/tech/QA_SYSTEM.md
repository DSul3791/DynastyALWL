# The QA system: how Dave's question page works (reusable kit)
Written 2026-10-22 by the Guru. Goal: one phone-friendly page where the owner answers questions and checks things, with every answer saved where the team can read it. Built with GitHub files only: no server, no database, no cost.

## 1. Files (all in the repo on branch claude/generator-v2, folder questions/)
- `qa.html`: the page. One file, no libraries. Loads QUESTIONS.md live, writes answers back through the GitHub API.
- `QUESTIONS.md`: open questions. Block = `## id | question`, then `- choice` lines, or `[text]` for a typed answer, or `[check]` for a "Things to check" card (Yes / No + "Why not?"). Other lines are notes shown under the question.
- `ANSWERS.md`: answered questions (`Answer:`, `Answered:` UTC). Answering moves a block from QUESTIONS.md to here.
- `LATER.md`: parked questions and old checks, not shown.
- `README.md`: format and Dave's setup steps.
- Support files in tech/: `QUESTION_OWED.md` (which thread waits on what), `TEST_QUEUE.md` (test asks from threads, batched into check cards), `DECISIONS.md` (every answer recorded), `tools/watch_answers.sh` (change watcher).

## 2. Hosting
- The real page lives in the main repo (questions/qa.html). A tiny stub, `qa.html` + `index.html`, lives in a separate PUBLIC repo `DSul3791/DynastyALWL-QA` with GitHub Pages (main, root): https://dsul3791.github.io/DynastyALWL-QA/
- The stub fetches the real qa.html from raw.githubusercontent.com (branch claude/generator-v2, cache about 5 min, CORS open) and rewrites itself with it. Page changes are pushed to the main repo only; the stub is never touched again.
- Requirement: the main repo must stay PUBLIC for the stub to load it. If it goes private the stub stops (decision repo-vis pending). Alternative then: serve the full page from the Pages repo and give it a token to read the private repo.
- The main repo is over GitHub's 1 GB Pages limit, which is why the page lives in its own tiny repo.

## 3. Token
- Dave's fine-grained token (Contents read and write, main repo only) is pasted once into the page. It lives in the browser's localStorage key `ghtok`, per address, so a phone and a PC each need it once. "Forget token" removes it.
- The token is never in any file. Check before every publish: grep qa.html for `ghp_` and `github_pat_`.
- Without a token the page shows only the token box and the buttons; no question text.

## 4. Page parts
- Header: Forget token (left), title, Dave's commands (right): status, audit, goodnight, idea.
- "Things to check": numbered cards (a note line `Image: questions/img/<file>.png` adds a picture; keep pictures under 300 KB), which build to pull, what to look at, Yes / No, "Why not?" box on No. Used only when a thread needs Dave to look; he does not pull builds otherwise.
- "Questions": multiple choice cards (recommended pick marked in the text), Save moves the answer to ANSWERS.md.

## 5. Flows
- Ask flow (BP-T52, Dave 23 Oct 23:23, replaces BP-T33/BP-T50 routing): the asking thread first checks HANDOFF.md, the DESIGN docs, questions/ANSWERS.md and DECISIONS.md; if the answer is not there it posts the card ITSELF with tools/qa_post.py and its recommendation and why (same card rules as BP-T51: Yes/No + Why-not, one question per card, picture pushed first, numbered steps for anything Dave does). Tyler is not in the path (he still sweeps ANSWERS into DECISIONS). Old line, kept for history: thread asks the Guru, the Guru answers from best practices or posts to the page; threads never write QUESTIONS.md; Dave answers when he can; the Guru reviews ANSWERS.md and replies to the thread.
- Test flow: thread adds a TEST_QUEUE.md line (build, what to look at); the Guru batches ready lines into `[check]` cards.
- Watching: `tools/watch_answers.sh` remembers the last commit SHA of ANSWERS.md and QUESTIONS.md and uses an ETag, so an unchanged poll is a free HTTP 304 and prints nothing. Run it under a Monitor so the AI wakes only on a printed line. Never generate questions because time passed.
- Style: numbered steps whenever Dave must act; succinct; "Question added: <title>".

## 5b. Poke button (Dave 17:34): wake Claude without a timer
- The page has a button "Tell Claude I answered". It posts one comment ("poke <UTC time> answered: <ids>") on a standing DRAFT pull request, DSul3791/DynastyALWL PR #1 in DSul3791/DynastyALWL-QA (branch qa-poke, base main) or, if the token only covers the main repo, PR #3 in DSul3791/DynastyALWL (branch qa-poke, base claude/generator-v2); the page tries QA first. NEVER merge or close it; never delete the branch.
- The coordinator session subscribes to PR #3 (subscribe_pr_activity); a comment wakes it, so idle cost is zero. On a poke: run `tools/watch_answers.sh once`, process only new answers (BP-T33), reply to the asking threads.
- Token permissions needed: Contents (Read and write, for answers), PLUS Issues (Read and write) AND Pull requests (Read and write) for the Poke comment, on the repos DynastyALWL and DynastyALWL-QA. Without them the poke fails with HTTP 403 (Dave's token had only Metadata read and Contents write on 2026-10-22). Old line kept for reference: Issues: Read and write on DynastyALWL (the token that already has Contents). Dave adds it once: GitHub > Settings > Developer settings > Fine-grained tokens > the token > Edit > Repository permissions > Issues: Read and write > Update. No new token to paste.
- Answered ids are remembered in the browser (localStorage "answered") and sent with the next poke.
- Fallback if the permission is not given: tell the coordinator in chat; the 5-minute watcher (tools/watch_answers.sh) still works.

## 5c. Watcher failure found 2026-10-22 and fixed
Answers sat unrelayed for 70 minutes. Causes: (1) a first run on an empty or new state file baselined silently, and a stale copy of the script kept doing so; (2) any HTTP error, rate limit or network failure was swallowed as "unchanged". Fixes: errors now print `ERROR ... HTTP <code>` and exit 10; the first run prints BASELINE; the state file defaults to /mnt/project-files/tech/.answers_seen (shared, permanent); `tools/answers_since.sh "YYYY-MM-DD HH:MM"` lists every answer newer than a time with no state at all. Rule: silence is never proof of "no change": a poke or a check without a clean exit 0 plus a successful read means UNKNOWN. A private repo needs GH_TOKEN for both scripts.

## 5d. Stub v2 (works with a private main repo)
The hosted page in DynastyALWL-QA asks for the token once (same localStorage key ghtok on github.io), then loads questions/qa.html from the main repo through the GitHub API with `Accept: application/vnd.github.raw`. No secret is in the stub. Poke comments go to DynastyALWL-QA PR #1 (public repo, no secrets in the comment).

## 6. Lessons and gotchas
- A locally saved copy of qa.html goes stale: Dave did not see a new button. Open the repo copy after Pull, or use the hosted page.
- GitHub "Raw" shows source in the browser, not the page; that is why a Pages address is needed.
- The first Pages build can sit "queued" for several minutes (it did, then cancelled by the next push); the page 404s until a build succeeds. Check Actions: "pages build and deployment".
- Pages cannot be reached from the cloud sandbox (403); the owner has to check on the phone.
- A saved page is only as good as its parser: a block with no choices, `[text]` or `[check]` shows a red error. Test any change with a mocked API (Playwright, phone width) before pushing.
- Keep qa.html free of secrets and of private details; the repo is public.
- Pull before editing QUESTIONS.md (the page itself edits it); a conflict is retried by the page up to 5 times.

## 7. Reuse and improvement ideas
- Reuse: copy questions/, the stub repo and watch_answers.sh; change REPO and BRANCH constants at the top of qa.html and the watcher.
- Later: friends hub (polls, suggestions, news posts; see IDEAS.md rows 2 and 2a), per-friend tokens in a separate data repo, a notification when a question is added.

## 8. Look and feel (v4, Dave 17:48)
Calm cream/dark theme, serif title (Daily Planet masthead idea saved for the friends page), sticky top bar with a menu button (sheet: Things to check, Questions, Dave's commands, Reload, Forget token), big 48 px tap targets, scalable font (clamp, readable on a 55-inch TV), always-visible bottom bar "Tell Claude I answered". Forget token asks "Are you sure?" (Cancel / Yes, forget it) before removing anything. Test at 390 px width with a mocked API (Playwright) after every change.
