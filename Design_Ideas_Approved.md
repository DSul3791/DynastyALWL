# Approved design records

Status records only; [DOC_MAP](docs/DOC_MAP.md) remains the main index. Each full specification stays in its owning topic file once. Approval provenance and implementation evidence are separate.

## Natural fog

- **Recorded status:** DIRECTOR-APPROVED instruction, Dave, 14 Nov 2026 16:06 UTC, thread “Make fog look and behave naturally”. The owning file preserves the full instruction as a verbatim transcription, beginning “here is my instruction on Fog”. This is stronger evidence than a bare legacy decision tag; the original chat was not independently retrieved in this audit. No new approval is granted here.
- **Full specification and source:** [Dave's fog instruction](docs/design/FOG_DESIGN_DAVE.md), unchanged; [immutable source transcription](https://github.com/DSul3791/DynastyALWL/blob/d0a00538473ab26cc1cd81b5661da186a5462c4b/docs/design/FOG_DESIGN_DAVE.md).
- **Scope:** appearance, occurrence, transitions, light, shelter and visibility behavior described there. Technical choices remain delegated. Adjustable visibility targets are not universal fixed distances; rain/morning/water tendencies are conditional, not automatic schedules. This record does not approve later tuning or certify implementation.
- **Implementation/evidence:** [fog record](Design_Ideas_Built.md#natural-fog).

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
