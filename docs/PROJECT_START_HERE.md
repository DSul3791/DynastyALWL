> Copy of the original in the project Library (/mnt/project-files/); paths in this file refer to the Library unless they name the repo.

# START HERE: the one entry point for a new agent (written 11 Nov 2026 by Morgan, design)

This is the index of the whole project folder `/mnt/project-files/` (shared by every agent) and of the git repo DSul3791/DynastyALWL. Read section 1, then use section 2 to find any other document. Every path below was checked against the folder listing on 11 Nov 2026 at 16:20Z.

Do not confuse: the repo has its own `docs/START_HERE.md` (commands and rules for working in the repo; see section 2.8). THIS file, `/mnt/project-files/START_HERE.md`, is the entry point for the project.

Status words: CURRENT = true now and maintained; DRAFT = working copy, repo version wins; HISTORICAL = old (October or early November 2026), bannered, keep for reasoning only; PRIVATE = opens only for Dave and people he shares it with.
Owner = the role (not a person; Dave is the only human) that keeps the document up to date. Roles: Steve (systems code), Sonny (terrain and water), Tyler (merge gate), Jamie (item data, names, docs commits), Kathleen (art, QA artifact), Morgan (design), Dino (heavy runs on Dave's PC), David4 (backup tester), MikeW (local checks, offline). The new coordinator reassigns roles.

## 1. Reading order
1. `/mnt/project-files/HANDOFF.md` down to the line `---`: state of the project, rules, names and terms, final updates.
2. Your role's handoff file: `/mnt/project-files/handoffs/<Role>_handoff_11Nov.md` (Steve, Sonny, Tyler, Jamie, Kathleen, Morgan, Dino, David4). If your role is new, the coordinator names the file.
3. `/mnt/project-files/handoffs/BACKLOG_11Nov.md`: the single backlog, by priority.
4. `/mnt/project-files/handoffs/UNINTENDED_RULES_AUDIT_11Nov.md`: which old rules Dave actually set and how each doubtful one was ruled.
5. `/mnt/project-files/design/decisions_pending.md`: all 85 decisions, every one DECIDED (authoritative).
6. `/mnt/project-files/handoffs/ARCHITECTURE_11Nov.md`: how the systems connect and what breaks what. Then `GUIDING_DOCUMENT.md` for the vision.
No new development starts until Dave ends handoff mode (see HANDOFF.md, Names and terms).

## 2. Document map

### 2.1 handoffs/ (written 11 Nov 2026 for the restructure; all CURRENT)
| File | Purpose | Owner |
|---|---|---|
| handoffs/Steve_handoff_11Nov.md | Systems role: what it owns, merged PR chain, lessons, next PR | Steve |
| handoffs/Sonny_handoff_11Nov.md | Terrain and water role: watershed chain, bakes, ore bodies, risks, bake order | Sonny |
| handoffs/Tyler_handoff_11Nov.md | Merge-gate role: merge rules, open PRs, close/keep calls | Tyler |
| handoffs/Jamie_handoff_11Nov.md | Item data role: file layout, id counters, naming rules, checks | Jamie |
| handoffs/Kathleen_handoff_11Nov.md | Art role: look rig use, material conventions, approved and rejected looks | Kathleen |
| handoffs/Morgan_handoff_11Nov.md | Design role: design docs, decisions, audits | Morgan |
| handoffs/Dino_handoff_11Nov.md | PC runner role: look-rig flags, bake and water commands, timings, worktrees | Dino (written by Dino; Morgan appended the final update) |
| handoffs/David4_handoff_11Nov.md | Backup tester role: gate scripts, lanes, flaky tests, what cannot be tested | David4 |
| handoffs/David4_handoff_11Nov.old_1515.md, Dino_handoff_11Nov.old_1435.md | Earlier drafts kept aside | HISTORICAL |
| handoffs/Steve_handoff_24Oct_1100UTC.md | Steve's October handoff | HISTORICAL |
| handoffs/FINAL_HANDOFF_REPORT_11Nov.md | The coordinator's final report for new agents: status, tags, PRs, water backup, Dave's PC, decisions, gaps, first jobs | CURRENT, Morgan |
| handoffs/BACKLOG_11Nov.md | The one backlog; threads append at the bottom | CURRENT, Morgan |
| handoffs/ARCHITECTURE_11Nov.md | System architecture and dependencies | CURRENT, Steve and Morgan |
| handoffs/DOC_AUDIT_11Nov.md | Which document is authoritative per topic; outdated, duplicate and contradictory docs | CURRENT, Morgan |
| handoffs/UNINTENDED_RULES_AUDIT_11Nov.md | Audit of rules nobody actually set, with the 11 Nov rulings | CURRENT, Morgan |
| handoffs/Tyler_rule_audit_11Nov.md, steve_rules_audit_11Nov.md, Sonny_rules_audit_11Nov.md | Each role's own rule audit (merged into the audit above) | CURRENT, each role |
| handoffs/branch_inventory_2026-11-11.md | Inventory of the 1032 git branches (none deleted) | CURRENT, Tyler |

### 2.2 Top level of /mnt/project-files/
| File | Purpose | Status / owner |
|---|---|---|
| HANDOFF.md | Project state, rules, names, final updates (below the `---` line it is October history) | CURRENT, Morgan |
| START_HERE.md | This index | CURRENT, Morgan |
| INDEX.txt | Older short index; points here | CURRENT, Morgan |
| GUIDING_DOCUMENT.md | Vision and design principles (creature-centred, written before the October restructure of work) | CURRENT but owner-less; decisions 41-42 say the new team owns it |
| GUIDING_PLAN.md | Plan for creature and world work | CURRENT but owner-less (as above) |
| ground_resources.md | What ore and ground resources a player can get | CURRENT, Sonny |
| ore_bodies_for_mining.md | Where the ore bodies are, for the mining design | CURRENT, Sonny |
| river_rebake_spec.md | Spec for re-baking rivers | CURRENT, Sonny |
| sawmill_spots_near_spawn.md, sawmill_test_spots.md | Candidate sawmill sites near spawn | CURRENT, Sonny |
| limestone_sand_near_spawn.md | Limestone and sand near spawn (decision 15) | CURRENT, Sonny |
| peaks_glacial_580h.md, peaks_landform_580h.md, follow_the_water_ws580v.md, flow_tie_audit.md, spring_damp_patch_note.md | Water chain research notes (branch ws580v) | HISTORICAL research, Sonny |
| BACKLOG.md, DAVE_TODO.md | Old lists | HISTORICAL (bannered stale); use handoffs/BACKLOG_11Nov.md |
| CREATURE_PROGRESS.md, CREATURE_REPORT_2026-11-07.md | Creature work status of 7 Nov 2026 | HISTORICAL |
| FLAG_AUDIT_8NOV.md, flags_sweep_9nov.md | Audits of code feature flags | HISTORICAL (flags were removed) |
| bug-list-2026-11-03-triage.md | Bug triage of 3 Nov 2026 | HISTORICAL |
| items_export.md, items_recipe_audit.md, items_review_stage1.md | Early item exports and reviews | HISTORICAL; use buildables/items_current.md |
| MikeW_handoff_2026-10-23.md, MikeW_LocalAgent_001_HANDOFF.md | MikeW's October handoffs | HISTORICAL |
| dave_pull_job_9nov.md, godotprojects_cleanup_9nov.md, animals_drink_check_job.md, gathered_icons_job.md, wolves_wild_check_job.md | One-off job briefs for Dino | HISTORICAL |
| water_dumps_INDEX.txt, *.log, *.png, *.txt (dumps, shots, logs) | Evidence from runs and screenshots | HISTORICAL evidence; water_dumps_INDEX.txt lists the dumps |

### 2.3 design/ (design documents)
CURRENT and authoritative in this folder:
| File | Purpose | Owner |
|---|---|---|
| design/decisions_pending.md | All 85 decisions with rulings. AUTHORITATIVE | Morgan |
| design/mining_review.md | Mining design review (rulings 28-35 apply) | Morgan |
| design/siege_note.md, spyglass_note.md, food_tabs_note.md | Designs for raids, spyglass and food tabs; decided, not built | Morgan |
| design/playtest_brief_10nov.md | What Dave is asked to look at when he plays | Morgan |
| design/part_c_code_plan.md | Code plan for the item system part C | Steve |
| design/hardware_lantern_text.md, ore_encyclopedia_text.md, encyclopedia_flips_10nov.md | Encyclopedia text waiting to go in (part B of the hardware text is queued) | Jamie |
| design/bog_iron_data_jamie.md, kit_hardware_review.md, kit_renames_jamie.md, item_changes_for_jamie.md, item_export_2026-11-10.md | Item data working notes and exports | Jamie |
| design/realistic_animals_plan.md, starter_island_fauna_gradient.md, wildmesh_scale_table.md | Animal plans and scale table (the scale table's file name contains a vendor name; decision 83 says docs must not name it; backlog P3) | Morgan |
| design/water_network_note.md, steve_join_waits.md | Water network and join-wait notes | Sonny, Steve |
DRAFT (repo copy `docs/design/` is master; each has a banner): design/item_system.md, progression.md, buildables_plan.md, wood_tier_note.md.
HISTORICAL (bannered): design/EARLY_GAME_*, FIRST_HOUR_WALKTHROUGH.md, CRAFTING_STATIONS_RULE.md, BUILDING_TIERS_AUDIT.md and _TABLE.md, ITEM_TRIM_*, GATE_*, PLAYABILITY_PREP.md, QA_ANSWERS_24OCT.md, WEIGHT_AUDIT_24OCT.md, WATER_ACTION_PLANS.md, WATER_LAND_TYPES.md, FISH_AND_FISHING_PLAN.md; design/item_master_list.md is a research list; design/research/ holds October reference research.

### 2.4 buildables/ (item and water reference)
| File | Purpose | Status / owner |
|---|---|---|
| buildables/items_current.md | The current item list (about 804 rows), regenerated from data by jamie/tools/items_table.py | CURRENT, Jamie |
| buildables/water_flow_rules_sonny.md | Authoritative rules for water pieces (s10 sawmill, s11 bog iron) | CURRENT, Sonny |
| buildables/hammer_audit.md, item_system_review.md, part_c_triage.md | Review notes behind the item system | HISTORICAL |

### 2.5 kathleen/, steve/, jamie/, sonny/, tyler/
| Path | Purpose | Status / owner |
|---|---|---|
| kathleen/art_rules_audit_11Nov.md | Art role rule audit | CURRENT, Kathleen |
| kathleen/parked/ and kathleen/*.patch (bog_iron_draft.patch, gear_ghosts.patch, held_branch.patch ...) | Approved but unmerged art patches, including the lantern glow and _show_bog hookup | DRAFT, Kathleen |
| kathleen/buildables_look_vocabulary.md | Names for building looks | CURRENT, Kathleen |
| kathleen/*_sheet.png | Look reference sheets | CURRENT evidence |
| kathleen/tests_*.json | Test lists for gate runs | HISTORICAL |
| steve/mining_note.md, pickaxe_path.md, fake_cave_wall_note.md | Mining design notes from the systems side | DRAFT, Steve |
| steve/*_tests.json, tests_*.json (including ws2_tests.json) | Test lists the gate scripts run | CURRENT tooling, Steve and David4 |
| jamie/cold_read_11Nov.md | Jamie's cold read of the handoff set, 48 items, all fixed 11 Nov 2026 | CURRENT, Jamie |
| jamie/rule_audit_items_11Nov.md | Jamie's rule audit | CURRENT, Jamie |
| jamie/tools/ (allchecks.sh, econ.py, export_items.py, hcount.py, items_table.py, jedit.py ...) | Scripts for editing and checking item data | CURRENT, Jamie |
| sonny/*.png | Terrain pictures | HISTORICAL evidence |
| tyler/held-prs-2026-11-05.md | Tyler's running merge log (line 1 is the current main) | CURRENT, Tyler |
| tyler/BEST_PRACTICES.md, FINDINGS.md, cloud-gate-setup.md | October process notes | HISTORICAL (decision 67) |

### 2.6 Other folders in /mnt/project-files/
| Folder | Purpose | Status |
|---|---|---|
| water/ | Scripts and notes for the water chain (check_record.py, chain_stages_speed_note.md, ...) | CURRENT tooling, Sonny |
| tech/ | October technical documents (about 169 files: HANDOFF.md, DECISIONS.md, BUG_LIST.md, CONCERNS_*, plans) | HISTORICAL |
| handoff/ | October per-thread handoffs | HISTORICAL |
| art/, art-checks/, art_requests/, items/, flora/, goals/, goalpads/, erosion/, terrain_b/, trees/, ui/, sound/, inventory/, engine/ | October design and art notes and shots | HISTORICAL; the art master is the repo `art/Art_Direction.md` (decision 82) |
| proposed_removals/ | Files moved aside instead of deleted (README.md, REMOVALS.md list each) | CURRENT, any role |
| docs/archive/, backup/, backlog/, drafts/, reports/, design_notes/, references/, previews/, maps/, tiles/, tools/, uploads/, publish/ | Archives, shots, one-off notes, uploaded files | HISTORICAL; uploads/hearth/ holds files Dave uploaded |

### 2.7 The two artifacts (PRIVATE)
| Link | Purpose | Status |
|---|---|---|
| https://claude.ai/artifact/RLL5SvjeFtdfCtTmE6wjHy | Decisions page for Dave, items 1-85 with the full question text of 41-55 and 82-85 | PRIVATE convenience view; the authoritative record is design/decisions_pending.md |
| https://claude.ai/artifact/YJFeey3aK33dQyrTGtoFDd | QA page (Kathleen): look checks and art questions for Dave | PRIVATE; its cards are playtest checks (decision 40), not open decisions |

### 2.8 In the git repo DSul3791/DynastyALWL (public; main is master for everything here)
| Path | Purpose | Status / owner |
|---|---|---|
| docs/START_HERE.md | Commands and working rules for agents in the repo | CURRENT, Jamie |
| docs/design/item_system.md, progression.md, buildables_plan.md, wood_tier_note.md | MASTER copies of the item system, progression, buildables and wood tier design | CURRENT, Morgan and Jamie |
| HANDOFF.md (repo root) | The commands sheet only (not the project handoff); PR #1028 marks it | CURRENT, Jamie |
| PROTOCOL.md | Wire format of client-server messages; check it before adding a protocol number | CURRENT, Steve |
| RULES.md, CONTROLS.md, ART_DIRECTION.md, art/Art_Direction.md | Working rules; controls; art practice (ART_DIRECTION.md) under Dave's master art/Art_Direction.md | CURRENT |
| docs/DOC_MAP.md | Repo doc map: status of every repo document (refresh queued, Jamie) | CURRENT, Jamie |
| DESIGN_REJECTED.md (repo root) | Ideas Dave rejected; the seven rejected name words are to be added (decision 49, queued) | CURRENT, Jamie |
| docs/archive/ | Archived (retired) documents, by month | HISTORICAL |
| ARCHITECTURE_BUDGET.md, DESIGN_PRINCIPLES.md, DESIGN_IDEAS.md, BIG_PICTURE.md and about 60 more .md files at the repo root, plus docs/*.md (water, flora, fauna, items handovers) | Older design and spec documents; which are current is in docs/DOC_MAP.md and handoffs/DOC_AUDIT_11Nov.md | MIXED; check DOC_MAP before trusting one |
| data/ (data/items/*.json and others) | The game data; never edit by hand-guess, use jamie/tools | CURRENT, Jamie |

Keep this file current: when a document is added, moved or retired, change its row here and in INDEX.txt.
