# qa branch: Dave's question page data

This branch holds only `questions/`: the QA page (`qa.html`), open cards (`QUESTIONS.md`) and answers (`ANSWERS.md`).
It is kept apart from `main` so the phone page and `tools/qa_post.py` can save straight to it; `main` takes code only
through pull requests.

- Read answers from a code checkout: `git fetch origin qa && git show origin/qa:questions/ANSWERS.md`
- Post a card: `python3 tools/qa_post.py ...` (from a `main` checkout; it clones this branch, appends and pushes)
- The public stub (DSul3791/DynastyALWL-QA, qa.html) loads `questions/qa.html` from this branch.

Never merge this branch into `main`, and never merge `main` into it.
