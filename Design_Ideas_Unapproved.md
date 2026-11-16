# Design ideas awaiting approval or source verification

[DOC_MAP](docs/DOC_MAP.md) remains the index. This file separates proposals from recorded decisions awaiting source verification; missing sources neither withdraw decisions nor verify legacy **[Decided]** tags.

Future Approved records hold each full verified specification once, with approval source/date. Built records link to it and record commits, checks and gaps; built does not mean tested or player-verified. Neither file is created without supporting material.

## Aging and lifespan

Source: [DESIGN_IDEAS at bcd0290, sections 6.1, 7.3 and 7.4](https://github.com/DSul3791/DynastyALWL/blob/bcd029086b5148a38f070b68f9ed073c41f4a944/DESIGN_IDEAS.md#61-aging-and-death). Extracted 16 Nov 2026; original approval sources/dates were not established in the scoped review. Wording, tags, numbers and qualifications below are retained from that snapshot. Section numbers inside the preserved passages refer to [DESIGN_IDEAS](DESIGN_IDEAS.md), not this file.

### Recorded decisions — SOURCE UNVERIFIED

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

### Ideas and proposals — not approved

- **[Idea]** In their early 20s, players will hopefully settle down, establish a home and a spouse, and make that their base of operations.
- **[Idea]** The base can be in a town that belongs to another player or to the player. A town belonging to the server was also mentioned. The developer-built starter town (Section 8.1) is the first such town.
- **[Idea]** Couples realistically keep having children, about one every year or two, and twins are possible. That is one every 15 to 30 real days, or about a dozen children between parent ages 22 and 40 over about nine months of real time.
- **[Idea]** Population control: if a family has many children, one might fall sick and die or have a farming accident.
- **[Proposed]** Tie that risk to conditions the player can see and influence (poor food, a crowded house, no healer nearby, unsupervised dangerous work) plus a low baseline of childhood illness for every family, instead of a penalty for family size. Food, housing and land costs make a large family a real expense. Child death is emotionally heavy and can affect age ratings, so it may need gentle handling.
- **[Proposed]** Ownership held at the **dynasty** (family line) level, so nothing needs transferring when a character dies. This is consistent with the heir inheriting everything that remains.
- **[Proposed]** Skills should feel competent in tens of hours and mastered in a few hundred, so a character gets time at the peak before aging slows them. That much play time needs enough depth to stay interesting.
- **[Proposed]** An NPC who starts at 25 and dies at 62 lives about 18 real months. A child takes about 9 real months to reach 18. A town's population therefore turns over in about two real years, so births, marriage and migration matter. Birthdays come every 15.2 real days.

### Qualifications and source-review questions

- [Retirement, section 6.7](DESIGN_IDEAS.md#67-succession-inheritance-and-the-dynasty): the approximate pacing target is qualified by voluntary retirement with no fixed age.
- [Extended life, section 6.10](DESIGN_IDEAS.md#610-extended-life-and-hiding-it): wishes are an exception to ordinary aging; its speed tiers remain proposals.
- [Clock, sections 7.2](DESIGN_IDEAS.md#72-the-time-ratio-and-the-calendar) and [7.6](DESIGN_IDEAS.md#76-the-server-clock): interpreting “survive downtime” as persistence, with advancement paused, needs source verification.
- [NPC population, section 8.2](DESIGN_IDEAS.md#82-npc-population): reconcile the starting-age wording later. [Section 8.1](DESIGN_IDEAS.md#81-towns) retains the player major-illness exclusion when reading sickness above.
- Approval provenance and current runtime aging remain unverified. Full children, death, succession, population and wish specifications stay in [DESIGN_IDEAS](DESIGN_IDEAS.md).

### Consolidation receipt

[Section 7.3's repeated lifespan paragraph](https://github.com/DSul3791/DynastyALWL/blob/bcd029086b5148a38f070b68f9ed073c41f4a944/DESIGN_IDEAS.md#73-lifespan-targets) is covered by the retained pacing and clock passages; its distinct tuning expectation and alternative-ratio example remain verbatim. Original numbered headings retain routes.
