> Copy of the original in the project Library (/mnt/project-files/); paths in this file refer to the Library unless they name the repo.

# Final handoff report for the new team (11 Nov 2026, 16:25Z). Written by Morgan from the coordinator's report of 16:04Z and HANDOFF.md's final update.

Read /mnt/project-files/START_HERE.md first (reading order and a map of every document). Paths below refer to the project Library (/mnt/project-files/) unless they start with a drive letter (Dave's Windows PC) or name the git repo DSul3791/DynastyALWL.

## 1. Status
Handoff is complete as of 11 Nov 2026. All nine old agents finished; their work is merged or preserved in named branches; the handoff documents are on the shared drive; all 85 decisions are decided. Handoff mode (Dave's freeze: no new development, docs only) continues until Dave ends it in writing; the new coordinator asks him.
Roles (names are roles, not people; Dave is the only human): Coordinator (talks to Dave, holds his approval authority), Steve (systems code), Sonny (terrain and water), Tyler (merge gate), Jamie (item data, names, docs commits), Kathleen (art, QA artifact), Morgan (design), Dino (heavy runs on Dave's Windows PC), David4 (backup tester), MikeW (offline since 8 Nov 2026).

## 2. Code state
- Main branch: d7c65e193c161461dd4941968f99ff6cc55a62df, tag handoff-2026-11-11-final (tag object cf302163921fd59aeee6b4fa1a32b1a3dfd7d682). Tests: 155 pass, 0 fail (the subset David4 can run without the water record).
- Last fully tested checkpoint: 34df337e606de7ed2171d856358ee3056387e879, tag handoff-2026-11-11 (tag object 432095a1). Full suite: 342 pass, 0 fail.
- Merged on 11 Nov 2026: the Steve chain (four stacked PRs #1002 #1004 #1006 #1007), #1003, #1020 to #1025, #1011 (and #1009, #1017, #999, #1018 earlier). Bog iron (#996 #997 #1019) is live.
- Parked on purpose (open): #474 (water foam texture: keep, merge main in, look check), #596, #483. Branches of closed PRs #883, #525, #529 to #532 are kept. 1032 branches were inventoried (handoffs/branch_inventory_2026-11-11.md); none deleted.
- Click list for Dave (docs only, CI green, non-author review comments left; open on 11 Nov 2026 at 16:12Z): https://github.com/DSul3791/DynastyALWL/pull/1026 (head 3417ec1d), https://github.com/DSul3791/DynastyALWL/pull/1027 (head d64fc329), #1028 (Jamie, head 3d904ef3) and #1029 (Jamie, head 7b1770da; adds docs/PROJECT_START_HERE.md and docs/FINAL_HANDOFF_REPORT_11Nov.md, copies of the Library originals). If Tyler is refused by GitHub, Dave clicks Merge. After they merge, main moves past d7c65e19; Dino adds a new tag from the PC (Tyler cannot push tags).
- Things that cannot be tested without the PC or a GPU (see handoffs/David4_handoff_11Nov.md): anything visual or audible.

## 3. Water record (biggest risk, reduced)
The water record (about 1 GB, 129 files, record_sha 1db3b4cfd34de688a20144bc53a524bebf927d96) is the stored river-flow data the terrain bake reads. It is gitignored. Live copy: E:\Software\godotDev\probe_bake\worlds\base_world\record. Verified backup (decision 53, byte-identical, README beside it): E:\Software\godotDev\_WaterFile\record. Both are on drive E:, so a copy on a second drive or in the cloud is still wise (needs Dave's say-so). A bake without the record silently rule-bakes every tile. Never bake terrain on David4 (it has no record).

## 4. Dave's PC (Windows) state
- E:\Software\godotDev cleaned: 274 agent items moved to _AGENT_CLUTTER_11Nov for Dave to delete. Kept: DynastyALWL_ProjectBackups (Dave's real backups), DynastyALWL_Evidence, probe_bake, _WaterFile, gate_pc*. probe_pond (an old 8 Nov bake checkout) is left in place because of uncommitted .tile and .water edits; Dave decides.
- C:\GodotProjects\_DELETE_ME (11.95 GB): Dave approved deleting; Windows blocked Dino; Dave deletes it himself (Shift+Delete).
- Git worktrees remaining: Dave's checkout, tylerrun/wt167, gate_pc_claude to gate_pc_claude5, probe_bake, probe_pond.
- Dave runs the game from the Godot editor with F6 (Run Current Scene), not from an exported build (confirmed by Dave on 11 Nov 2026).

## 5. Documents produced (paths in the Library)
START_HERE.md (index); HANDOFF.md (state, rules, names, final updates); handoffs/<Role>_handoff_11Nov.md for Steve, Sonny, Tyler, Jamie, Kathleen, Morgan, Dino, David4; handoffs/BACKLOG_11Nov.md (the single backlog); handoffs/ARCHITECTURE_11Nov.md; handoffs/DOC_AUDIT_11Nov.md (authoritative document per topic); handoffs/UNINTENDED_RULES_AUDIT_11Nov.md (+ role audits Tyler_rule_audit, steve_rules_audit, Sonny_rules_audit, kathleen/art_rules_audit_11Nov.md, jamie/rule_audit_items_11Nov.md); jamie/cold_read_11Nov.md (cold-read results, all fixed); design/decisions_pending.md (all decisions, authoritative). Master design copies live in the git repo docs/design/; the Library copies are working drafts.

## 6. Decisions
All 85 are decided (by Dave, or by the coordinator at Dave's request on 11 Nov 2026). Authoritative record: design/decisions_pending.md. No decision is open for Dave. Two overrules by Dave: item 81 (water, quoted below) and that handoff rules stand. Convenience view for Dave only, private until he shares it: https://claude.ai/artifact/RLL5SvjeFtdfCtTmE6wjHy. Look checks on the QA page (https://claude.ai/artifact/YJFeey3aK33dQyrTGtoFDd, private) are playtest checks (decision 40), not open decisions.

## 7. Dave's standing rules (verbatim)
- Going-forward rule (11 Nov 2026): "no agent may silently avoid a reasonable solution because of an obscure documented restriction. The agent must identify the blocking rule, explain the conflict, and request a decision when needed. Our documentation must preserve my intentions, not accidentally invent new limitations."
- Water (11 Nov 2026): "Sonny decides water with no 'Buts'. If I notice something, I will make it something to fix later." No QA cards are needed for water decisions.
- Rulings that changed old rules: replaced code is deleted, documents are archived (61); bake speed is a target (62); no copper-tools ban (70); any metal hammer builds any tier (73); no 3-ingredient rule (69); names carry a tier word only where an item comes in more than one material (71). Full list: design/decisions_pending.md.
- Process: only the coordinator approves; a question from Dave is not a go; backups and zips only on Dave's say-so; no tests or bakes in the cloud; Tyler merges only on green CI plus David4 PASS on the exact head (docs only: CI plus a non-author comment); keep one persistent thread per role (Dave's rule for the current setup; the new coordinator asks Dave before changing it).

## 8. Known gaps
Visuals and sound were not looked at on 11 Nov 2026 (Dave has not played the bow, lanterns or bog iron chain). A bought animal-pack vendor name remains in data/animals/models.json and comments in src/client/animal_view.gd (backlog P3; decision 83). The water record backup is on the same drive as the live copy. Fortified/raid/HP, mining, spyglass and food tabs are designed and decided but not built. Items 41 and 42 (who owns creature and world work) wait for the new team. The source list of "Law 7" was not found (it is superseded by decision 81).

## 9. Suggested first jobs (after Dave ends handoff mode)
1. Steve: "spend the lowest group member first" PR (approved), plus the BUILD_STOCK_M comment fix.
2. Kathleen: parked lantern glow and _show_bog hookup (patches in art/parked/ and kathleen/parked/).
3. Jamie: queued docs (decisions 44 to 46 and 49), two hardware encyclopedia lines, taking trap sets out of the encyclopedia.
4. Sonny and Steve: mining first slice (surface adit), then weir piece (79) and water-table layer (80).
5. Dino: lantern shot 3, outcrop reshoot, -55 degree lantern retake.
Full ordered list: handoffs/BACKLOG_11Nov.md.
