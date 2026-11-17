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

## Aging and lifespan

DIRECTOR-APPROVED under Dave’s 16 Nov 2026 instruction in Clauda Optimization: "if they are in the documents then they are from me." Explicit [proposals](Design_Ideas_Unapproved.md#aging-and-lifespan) remain separate; runtime is unverified.

Source: [DESIGN_IDEAS at bcd0290, sections 6.1, 7.3 and 7.4](https://github.com/DSul3791/DynastyALWL/blob/bcd029086b5148a38f070b68f9ed073c41f4a944/DESIGN_IDEAS.md#61-aging-and-death). Extracted 16 Nov 2026.

- **[Decided]** Players age. They can woo a partner and have children.
- **[Decided]** Characters start at age 20. Marriage and children are possible from age 18 at the earliest.
- **[Decided]** **Lifespan is drawn at birth** from a bell curve around 62 years with a spread of about 8, never below 45 or above 85, to account for genetics. Sickness, accidents and fights come on top of that.
- **[Decided]** For pacing, a typical character lives from 20 to about 62 (42 years) over about 21 months of real time, roughly 1,270 hours of play at 14 hours a week (Section 7). Retirement comes around 50, after about 15 months.
- **[Decided]** Children age too.
- **[Decided]** **One clock.** Everyone (players, families and NPCs) ages on the server clock at the same rate, whether or not the player is online. Ageing follows ordinary human rules: pregnancy lasts about nine months, women go through menopause, and a couple can have as many children as they choose to and as biology allows. One year of age is one calendar year of 365 game days, which at the default ratio of 24 (Section 7.2) is 15.2 real days. A pregnancy is about 11.4 real days, a child reaches 10 after about 152 real days and 18 after about 274. Time away ages a character (four weeks is about 1.8 years). The clock must survive server downtime (Section 7.6).
- **[Decided]** Spouses and children stay in the world while the player is away. Events such as bandit raids, dragons and sickness can affect them, which gives players a reason to return.
- **[Decided]** Fertility: marriage and children from 18 at the earliest; the chance falls gradually from 35; menopause at a random age between 45 and 55 set at birth; men stay fertile for life, with the chance dropping after 60.
- **[Decided]** The expected player plays 12 to 16 hours a week. This will be tested and tuned with the one time ratio (a ratio of 36 would give about 14 real months).
- **[Decided]** NPCs age on the same clock as players, from a random starting age (roughly 20 to 30) to a death age drawn from the same bell curve. Showing age as a number plus a life stage (child, young adult, adult, elder) is available.

### Qualifications and unresolved questions

- [Retirement, section 6.7](DESIGN_IDEAS.md#67-succession-inheritance-and-the-dynasty): the approximate pacing target is qualified by voluntary retirement with no fixed age.
- [Extended life, section 6.10](DESIGN_IDEAS.md#610-extended-life-and-hiding-it): wishes are an exception to ordinary aging; its speed tiers remain proposals.
- [Clock, sections 7.2](DESIGN_IDEAS.md#72-the-time-ratio-and-the-calendar) and [7.6](DESIGN_IDEAS.md#76-the-server-clock): stored clock persistence and whether time advances during server outages remain distinct questions; §7.6 describes paused advancement as a proposal. This migration does not settle it.
- [NPC population, section 8.2](DESIGN_IDEAS.md#82-npc-population): reconcile the starting-age wording later. [Section 8.1](DESIGN_IDEAS.md#81-towns) retains the player major-illness exclusion when reading sickness above.
- Related [family](Design_Ideas_Unapproved.md#children-and-family-growth), [death](Design_Ideas_Unapproved.md#death-and-rescue), [succession](Design_Ideas_Unapproved.md#succession-and-inheritance) and [population](Design_Ideas_Unapproved.md#npc-population-and-migration) records retain their own status.

### Consolidation receipt

[Section 7.3's repeated lifespan paragraph](https://github.com/DSul3791/DynastyALWL/blob/bcd029086b5148a38f070b68f9ed073c41f4a944/DESIGN_IDEAS.md#73-lifespan-targets) is covered by the retained pacing and clock passages; its distinct tuning expectation and alternative-ratio example remain verbatim. Original numbered headings retain routes.

## Children and family growth

DIRECTOR-APPROVED under [Dave's recorded-decision instruction](#aging-and-lifespan), 16 Nov 2026. [Proposals and questions](Design_Ideas_Unapproved.md#children-and-family-growth) stay separate; runtime unverified.

Source: [DESIGN_IDEAS §§6.6, 6.8–6.9](https://github.com/DSul3791/DynastyALWL/blob/bcdee5666bec5f7fadb4d418c9e14a264ea585c2/DESIGN_IDEAS.md#66-children-and-family-growth). Extracted 16 Nov 2026.

### Childhood and teaching

- **[Decided]** Having a child is a joint decision. The player discusses it with the spouse, they agree, and the pregnancy begins. It is not automatic and a bot-run household does not breed on its own.
- **[Decided]** A baby and young child are a cost on the household (food, care, the spouse's time), not a worker. The child becomes useful around age 10 to 12.
- **[Decided]** At about that age the player talks with the child about what direction to take and can set markers that steer them (farming, mining, a trade, adventure, schooling, being the heir). The child follows the markers according to their own interests and abilities.
- **[Decided]** The default for a child with no markers is idleness: play, little work, few skills. An unattended household therefore raises children with weak skills and a farm that stagnates.
- **[Decided]** An engaged player can teach the children, so different children can serve different branches of the dynasty (one runs the mine, others work the farm, some adventure). All of these bring wealth and options to the family.

### Adoption and inclusion

- **[Decided]** The game does not restrict who can be spouses. Same-gender couples, and any couple that cannot have children, are fully supported.
- **[Decided]** Dynasties can adopt children. A couple can apply to the local temple, or the temple can reach out to them.
- **[Decided]** Adoptable children come first from displaced NPCs: children under a set age from collapsed dynasties who have no parent.
- **[Decided]** A displaced child who still has a parent can come with that parent. The temple may introduce a displaced spouse with children, and the couple may choose marriage, adoption or both.
- **[Decided]** When there are not enough displaced NPCs, the server keeps a number of pre-generated orphans at each temple, with the number picked at random each week. There is also a random chance of a spouse with one or two children waiting at the temple.

### Dependencies and unresolved qualifications

- [Approved aging and fertility](Design_Ideas_Approved.md#aging-and-lifespan) and [birth-spacing proposals](Design_Ideas_Unapproved.md#aging-and-lifespan) are distinct; the joint-decision rule above explicitly says pregnancy is not automatic.
- [Inheritance and partial training](DESIGN_IDEAS.md#62-what-an-heir-inherits) retains the parental head-start idea and its unresolved size; [skills](DESIGN_IDEAS.md#54-skills) retains the wider learning design.
- [Succession and household limits](DESIGN_IDEAS.md#67-succession-inheritance-and-the-dynasty) qualifies eligibility and household size. [Adopted-heir eligibility](Design_Ideas_Unapproved.md#adoption-and-inclusion) remains a proposal; this migration does not place adopted children in the approved succession order.
- [Farming](DESIGN_IDEAS.md#51-farming-rhythm) retains distinct household labor and offline-work rules; [NPC population](DESIGN_IDEAS.md#82-npc-population) retains NPC-family behavior. Do not generalize a player-household pregnancy rule into an NPC-population ruling.
