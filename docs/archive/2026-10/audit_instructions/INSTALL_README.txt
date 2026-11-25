DYNASTY LOCAL AUDIT SETUP

1. Extract this ZIP into: C:\GodotProjects\DynastyALWL
   After extraction you should have:
   C:\GodotProjects\DynastyALWL\audit_instructions\MASTER_AUDIT.md
   C:\GodotProjects\DynastyALWL\audit_instructions\PHASE_1_INVENTORY.md
   ...through PHASE_6_VERIFICATION.md

2. Ensure Bionic workspace = C:\GodotProjects\DynastyALWL and that you are on your experimental Git branch.

3. Keep your short System Prompt in Bionic. Use one phase prompt at a time.

4. Qwen Phase 1 message:
   Read audit_instructions/MASTER_AUDIT.md and audit_instructions/PHASE_1_INVENTORY.md.
   Work only on Phase 1. Save results in audit_reports/qwen/.
   Verify saved files and stop after Phase 1. Do not start Phase 2.

5. For subsequent phases, change PHASE_1_INVENTORY.md to PHASE_2_AUTHORITY.md etc.
   Always tell the agent to read audit_reports/qwen/PROGRESS.md and resume the next incomplete batch.

6. When testing Ministral later, replace qwen with ministral and use a clean, independent audit report directory.

Note: these instruction files guide the agent but do not trigger execution on their own.
