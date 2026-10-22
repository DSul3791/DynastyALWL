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
