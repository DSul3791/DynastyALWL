
## bk-weekly | Backups older than 30 days are thinned to one per week. Which one do we keep forever from each week?
Weeks run Monday to Sunday.
- The LAST backup of the week, normally Sunday night: it holds the whole week's work (recommended)
- The OLDEST backup of the week, normally Monday: the state at the start of the week
- Decide later

## bk-trigger | How should the nightly backup start?
- When you say "goodnight", and MikeW checks that Godot is closed first (recommended: it only runs when you are done)
- Automatically at a fixed time, for example 2 AM (needs Godot closed by then; a failed night is reported in the morning)
- Both: goodnight, with the fixed time as a safety net if you forget
