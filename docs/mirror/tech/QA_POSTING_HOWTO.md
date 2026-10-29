# How a thread posts a card to Dave's QA page (BP-T47, Dave 2026-10-23 04:52)
Dave: threads may post straight to the QA page as long as they follow the card rules AND always make a recommendation. The QA page is Dave's to-do list (BP-T44): anything he must decide, test or do is a card.
## The one command (appends only, pushes to branch qa from a throwaway clone; your own branch is untouched)
  python3 tools/qa_post.py --id my-card --kind check --title "Should X do Y?" --note "What it means, plain words." --rec "Yes because Z."
Kinds: check (Yes/No plus Why-not), test (Yes it worked / No plus Notes, steps are numbered notes), picture (Picture taken / not taken plus Notes), text (a typed answer, only when truly needed). Add --dry-run to see the card without posting. If git is not available, write the same text into questions/QUESTIONS.md by the GitHub contents API (append only) following the template.
## Card template (what the tool writes)
  ## my-card | Should X do Y?
  Note: plain-words meaning, one short line each (numbered "1. ..." steps if Dave must DO something)
  Note: Recommendation: Yes because Z.     (your own, "X because Y")
  [check]        (or [test] / [picture] / [text])
## Rules (the Guru checks these)
1. One question per card. Never a list: one card per line.
2. Yes/No plus Why-not for decisions ([check]); TEST or PICTURE cards for things to do or look at, each with numbered steps and exact keys, ending in Yes/No plus Notes.
3. ALWAYS a recommendation and why ("--rec"). No recommendation, no card.
4. Anything Dave must do = numbered point form with exact button or file names.
5. Team tests first (BP-T46): attach what the team already tried; only human-judgment items go to Dave. In-game looks: "go to the spawn showroom, row N" (BP-T45). Pictures can always be attached.
6. Plain words a non-programmer reads once. No jargon, no "see the doc" (BP-T36): a plan is 5 to 10 numbered lines.
7. Nothing that says who something is for (BP-T42). Check the page for a card on the same topic first; the tool refuses a repeated id.
8. Never edit or remove a card; Dave may be answering. If you got something wrong, post a corrected card with a new id and tell the Guru.
## Guru's review (I keep my own jobs: page layout, the answers sweep, recording, merges)
I read new cards on each wake: I fix format and wording and dedupe, I never remove a card Dave may be answering, and I keep the page order (tests before design questions).
## After Dave answers
The page moves the card to questions/ANSWERS.md. The Guru sweeps answers, records them in DECISIONS.md and tells each owner what changed via the coordinator.
