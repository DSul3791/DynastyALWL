# Approved design records

Status records only; [DOC_MAP](docs/DOC_MAP.md) remains the main index. Each full specification stays in its owning topic file once. Approval provenance and implementation evidence are separate.

## Natural fog

- **Recorded status:** DIRECTOR-APPROVED instruction, Dave, 14 Nov 2026 16:06 UTC, thread “Make fog look and behave naturally”. The owning file preserves the full instruction as a verbatim transcription, beginning “here is my instruction on Fog”. This is stronger evidence than a bare legacy decision tag; the original chat was not independently retrieved in this audit. No new approval is granted here.
- **Full specification and source:** [Dave's fog instruction](docs/design/FOG_DESIGN_DAVE.md), unchanged; [immutable source transcription](https://github.com/DSul3791/DynastyALWL/blob/d0a00538473ab26cc1cd81b5661da186a5462c4b/docs/design/FOG_DESIGN_DAVE.md).
- **Scope:** appearance, occurrence, transitions, light, shelter and visibility behavior described there. Technical choices remain delegated. Adjustable visibility targets are not universal fixed distances; rain/morning/water tendencies are conditional, not automatic schedules. This record does not approve later tuning or certify implementation.
- **Implementation/evidence:** [fog record](Design_Ideas_Built.md#natural-fog).

## Succession order and final-child fallback

- **Status:** DIRECTOR-APPROVED, Dave, 16 Nov 2026, Clauda Optimization conversation. Dave specified: "all blood children are listed first. from the first wife to the last wife in order. all step children come next in order of mothers in the relationship." He clarified: "the spouses are in there as well at the bottom of each family list after the children." Dave then answered "yes" to the complete ordering and final-child fallback restated below, and instructed "make it so in the documents clearly."
- **Scope:** the offer order and mandatory final-child fallback at death or retirement. This is the full specification for those rules; other [succession/inheritance details](Design_Ideas_Unapproved.md#succession-and-inheritance) retain their own recorded status. This approval does not certify implementation, testing or player verification.

### Order of offers

Ask the named successor first, if there is one. If no successor is named, or the named successor refuses, use this list:

1. **All blood children first.** Group them by mother, from the first wife to the last wife in relationship order. Within each mother's group, list children oldest to youngest. Do not combine all blood children into a single global age sort.
2. **Then the spouses' family groups**, from the first spouse to the last in relationship order. Within each group, list that spouse's stepchildren (children from before the relationship) oldest to youngest, then the spouse herself. A spouse with no stepchildren still occupies the bottom of her otherwise empty group. All blood children therefore precede every stepchild and spouse.

Each eligible person may accept or refuse. A deceased person is skipped; an elderly or dead spouse cannot take over. Whoever accepts becomes the player's character and the sole successor to the whole dynasty.

For example, with two wives who each have blood children and stepchildren, the ordinary offer order is: first wife's blood children; second wife's blood children; first wife's stepchildren; first wife; second wife's stepchildren; second wife. Children within each group are ordered oldest to youngest.

### Final-child fallback

If every eligible person refuses, **the final living eligible child on the combined list must accept**. Identify that child by their position in the list, ignoring spouse entries; do not select the globally youngest child across all families. This may be a stepchild. If there are no eligible stepchildren, it is the final eligible blood child in the blood-child groups.

Spouses after that child still receive their ordinary opportunity to accept. Only after everyone else refuses does the mandatory fallback override that child's earlier refusal. The last spouse is never compelled by this rule. A player with a surviving eligible child therefore keeps the dynasty.

### Superseded wording

This ruling replaces the former global oldest-to-youngest blood-child order and the ambiguous description of the fallback as the "youngest child" or "last person on the line." The former text remains recoverable at [the pre-clarification source](https://github.com/DSul3791/DynastyALWL/blob/cf16e87da52a48bd8a809f667fe6330868dfa39a/Design_Ideas_Unapproved.md#handover-chain-succession). The rule selects the final child in the approved family order, even when a spouse follows them.

## Successor's first responsibility — estate debts

- **Status:** DIRECTOR-APPROVED, Dave, 16 Nov 2026, same conversation: "the first job a successor must do is arrange payments of any debts owed by the estate." Dave explicitly deferred addressing this future gameplay dynamic.
- **Design note:** The successor's first responsibility is to arrange payment of debts owed by the estate.
- **Deferred:** Record this requirement only. Payment mechanics, terms, enforcement and implementation are future work and are not addressed by this documentation change. This note does not resolve other estate/debt questions or authorize code changes.
