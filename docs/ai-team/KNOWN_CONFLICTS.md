# Identified legacy conflicts — verify before editing
**Status: UNRESOLVED IN REPO — do not silently supersede. Not yet remediated in GitHub. Source reads from current default branch on 11 Nov 2026.**

1. `docs/START_HERE.md` (Rules section): 'There is NO daily branch (Dave, 2 Nov 2026)' and `claude/<agent>-YYYYMMDD` -> direct main PR. **Superseded by Dave's later approval of committed nightly dev and gated main.** Preserve old decision as historical; update this active entry when installing.
2. `RULES.md` (Git section): old `DailyDev_YYYYMMDD` daily branch and 'main until Dave says go' plus inconsistent 'nothing deleted' next to decision 61. Reconcile to new `dev` workflow and approved replaced-code deletion/archive-doc policy. Do not assume every line is still current.
3. `docs/DOC_MAP.md` is explicitly marked STALE and still cites older agents, owners and documents. Refresh index during migration; existing Library `START_HERE.md` says audit determines current authority.
4. `docs/START_HERE.md` says all heavy test runs only on Dave's PC; actual handoff uses Dino and David4 roles, and David4 cannot run water data gates. Define gate-per-machine explicitly, preserving **no cloud heavy Godot tests**.
5. `RULES.md` refers to old QA branch workflow; current handoff reports private QA artifact plus authoritative `design/decisions_pending.md`. Verify real status before updating links; do not invent publication or access.
6. `docs/design/progression.md` describes a Bone Needle 'coordinator ruling, Dave to see' and several workbench/forge naming details. A coordinator decision is not automatically a Dave verbatim approval. Audit provenance before treating ambiguous wording as locked gameplay law.
7. Library `HANDOFF.md` says the earlier configuration uses persistent threads per role. The desired replacement is ephemeral task sessions, but existing freeze and coordinator handoff requirements continue until approved activation.
8. Water law 81 grants Sonny scope to decide water, but doesn't override safeguards, other roles' interfaces or future Dave explicit instructions.
9. Live `main` was independently read as `ff650afb811088720ea3f046fbac128588a76821` (11 Nov 2026), a documentation merge #1029. Final handoff and live SHA agree as of the check. Recheck before installing or creating dev.
10. No `dev` branch was found in a name search during preparation. Confirm again before attempting creation; treat creation as a deliberate migration step, not something already done.

Resolution format: file + clause -> previous intent/source -> proposed replacement -> affected docs and tests -> reviewer -> director approval if material -> commit. Archive historical docs; do not quietly erase the reasons behind old practices.
