# Questions for Dave

**RULE (Dave): only real questions with pickable answers go in QUESTIONS.md.** Multiple choice, or a short text box only where a typed answer is truly needed. No tasks like "look at the lake" or "test build X"; those stay in chat.

Open `questions/qa.html` (see steps below). It lists every question in `QUESTIONS.md`. Dave picks an answer, presses Save, and that one question moves to `ANSWERS.md` and is deleted from `QUESTIONS.md`.

## Format of QUESTIONS.md

One block per question. Header line `## id | question text`, then either choice lines or the word `[text]`:

```
## forge-size | Should the Large forge stay admin-only?
- Yes, admin-only
- No, let players build it

## moose-name | What should we call the moose trail?
[text]
```

- id: short, unique, no spaces or `|`. Add to the end of the file; any thread may add.
- Choices: lines starting `- `. Text question: a line `[text]`.
- A block with neither shows a red error in the page and cannot be saved.

Answers appear in `ANSWERS.md` as `## id | question`, then `Answer: ...` and `Answered: date`. Threads read it there.

## Dave: how to open the page (once)

1. Make a token: GitHub > Settings > Developer settings > Fine-grained tokens > Generate. Repository: only DynastyALWL. Permission: Contents = Read and write. Copy it.
2. Save `qa.html` to your computer (open it on GitHub, Raw, Save as) and double-click it.
3. Paste the token in the box and press Remember. It stays in that browser only.

## Notes under a question (added by Steve_002)
Lines under the header that are not `- ` choices and not `[text]` are shown as short paragraphs under the question (used by the grouped test card: one line per thing to look at). The page is titled "Questions & Tasks for Dave"; there is no Refresh button (press F5).

## Style (Dave 17:07)
Whenever Dave must do something, write it as numbered point form (1. 2. 3.), one action per line, with exact button or file names.

## Things to check (Dave 17:10)
Dave does not pull or run builds until a thread needs him to look. Then a check card goes in QUESTIONS.md (the Guru batches requests from TEST_QUEUE.md so he tests several things in one pull). Format:

```
## chk-trees | Check trees: do they look good?
[check]
Build: 648 (Pull, close the game fully, press Play)
Look: walk to the spawn lake and look at the pines on the east bank
```

The page shows a numbered "Things to check" list with Yes / No and a "Why not?" box that appears on No. The answer lands in ANSWERS.md as `Yes` or `No: reason`.

## Test and picture cards (page v8, Dave 2026-10-23)
- `[test]` card: title = "Please test this, look for X." Notes lines give the steps. Dave picks "Yes, it worked" or "No, it did not work" and always has a Notes box.
- `[picture]` card: title = "Please take a picture of this at x, z." Dave picks "Picture taken" or "Picture not taken", with the same Notes box.
- Keep instructions specific and simple: what to do, where, what to look for.

## Comments and revisit (page v12, Dave 2026-10-30)
- Every card has a Comments box. Whatever Dave types is saved after the answer as ` | Comment: ...`.
- Every card has a "We should revisit this later" button at the bottom. It records `Revisit later` (with the comment) in ANSWERS.md, copies the card to LATER.md and removes it from QUESTIONS.md.
- Every multiple-choice card carries a `Note: Recommendation: X because Y` line, written by whoever posts it.
