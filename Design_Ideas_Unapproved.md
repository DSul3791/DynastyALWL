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


## Children and family growth

Source: [DESIGN_IDEAS §§6.6, 6.8–6.9](https://github.com/DSul3791/DynastyALWL/blob/bcdee5666bec5f7fadb4d418c9e14a264ea585c2/DESIGN_IDEAS.md#66-children-and-family-growth), extracted 16 Nov 2026. Original approval sources/dates remain unverified; preserved section numbers refer to DESIGN_IDEAS. Existing legacy tags retain their recorded meaning, without new approval.

### Childhood and teaching

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Having a child is a joint decision. The player discusses it with the spouse, they agree, and the pregnancy begins. It is not automatic and a bot-run household does not breed on its own.
- **[Decided]** A baby and young child are a cost on the household (food, care, the spouse's time), not a worker. The child becomes useful around age 10 to 12.
- **[Decided]** At about that age the player talks with the child about what direction to take and can set markers that steer them (farming, mining, a trade, adventure, schooling, being the heir). The child follows the markers according to their own interests and abilities.
- **[Decided]** The default for a child with no markers is idleness: play, little work, few skills. An unattended household therefore raises children with weak skills and a farm that stagnates.
- **[Decided]** An engaged player can teach the children, so different children can serve different branches of the dynasty (one runs the mine, others work the farm, some adventure). All of these bring wealth and options to the family.

#### Ideas and proposals — not approved

- **[Proposed]** Teaching speed depends on the parent's own skill in the trade and the time they spend with the child. This links to the partial-training idea in Section 6.2.
- **[Proposed]** The child's own traits can pull against the markers, so a strong push against a child's nature gives slower, grumbling progress.

#### Open questions

- **[Open]** How much time teaching costs the parent, and whether NPC tutors or apprenticeships can stand in for the parent.

### Non-successor siblings

#### Ideas and proposals — not approved

- **[Idea]** A sibling outside the succession line decides for themselves, using their traits, skills, memory and preferences, whether to stay with the dynasty or break off and live their own life.
- **[Idea]** A sibling might marry another player and join that player's dynasty, or take a local job (temple, inn) and become a town character who keeps a tie to the family.
- **[Idea]** A sibling who leaves chooses between their own house and living at the homestead, where their income counts toward the dynasty's income.

#### Open questions

- **[Open]** All of this is deferred. It needs the NPC decision system (traits, preferences, language) and the household income model first.

### Adoption and inclusion

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** The game does not restrict who can be spouses. Same-gender couples, and any couple that cannot have children, are fully supported.
- **[Decided]** Dynasties can adopt children. A couple can apply to the local temple, or the temple can reach out to them.
- **[Decided]** Adoptable children come first from displaced NPCs: children under a set age from collapsed dynasties who have no parent.
- **[Decided]** A displaced child who still has a parent can come with that parent. The temple may introduce a displaced spouse with children, and the couple may choose marriage, adoption or both.
- **[Decided]** When there are not enough displaced NPCs, the server keeps a number of pre-generated orphans at each temple, with the number picked at random each week. There is also a random chance of a spouse with one or two children waiting at the temple.

#### Ideas and proposals — not approved

- **[Proposed]** Requirements to adopt: the dynasty has a home, enough income to raise a child, and a good enough reputation. A child who is adopted becomes family and can become the successor.

#### Open questions

- **[Open]** How an adopted child's traits and background are generated, how the temple decides between applicants, and the age limit for a child to count as adoptable.
- **[Open]** Whether other routes should exist (guardianship of a relative's child, fostering) and how they differ from adoption.

### Dependencies and unresolved qualifications

- [Aging and fertility](#aging-and-lifespan) includes birth-spacing ideas; the joint-decision rule above explicitly says pregnancy is not automatic.
- [Inheritance and partial training](DESIGN_IDEAS.md#62-what-an-heir-inherits) retains the parental head-start idea and its unresolved size; [skills](DESIGN_IDEAS.md#54-skills) retains the wider learning design.
- [Succession and household limits](DESIGN_IDEAS.md#67-succession-inheritance-and-the-dynasty) qualifies eligibility and household size. Adopted-heir eligibility above is a proposal; do not silently reconcile it with the recorded blood-child chain.
- [Farming](DESIGN_IDEAS.md#51-farming-rhythm) retains distinct household labor and offline-work rules; [NPC population](DESIGN_IDEAS.md#82-npc-population) retains NPC-family behavior. Do not generalize a player-household pregnancy rule into an NPC-population ruling.

## Death and rescue

Source: [DESIGN_IDEAS §§6.1 and 6.5](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/DESIGN_IDEAS.md#61-aging-and-death), extracted 16 Nov 2026. Legacy decisions remain SOURCE UNVERIFIED; original tags and complete nested passages are preserved. Section numbers refer to DESIGN_IDEAS.

### Danger, rescue and logging out

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Decided]** Because offline characters stay vulnerable, the downed timer keeps running while the player is offline.
- **[Decided]** Co-op: friends in the same friends group (Section 6.13) can tend animals and harvest crops for an absent owner, with permission.

#### Ideas and proposals — not approved

- **[Idea] (brainstorm)** Not every defeat downs a character for rescue. Bandits and the like may knock a player out, rob and mock them, and leave them alive. After a brief blackout (about 20 to 30 seconds, not settled) the player wakes and can try to get away: crawl, limp, hide, seek cover, bandage, call for help, abandon gear or head home while help may be coming. The character is never left helpless just waiting for an NPC. To settle: how this fits the ARK-style downed state above (which defeats down you, which knock you out briefly).
- **[Idea] (brainstorm)** Waking can be dangerous in itself: in a cave, standing up may draw the creature that knocked you out, while crawling or staying hidden may get you out. Going alone should feel risky, which makes companions worth bringing.
- **[Idea] (brainstorm)** Escape should be frightening and costly but never twenty minutes of empty, forced crawling: meaningful choices (when to move, hide, stand, bandage, call for help, drop gear), not punishment by boredom. Being hurt must not mean being unable to play.
- **[Idea] (brainstorm)** Injuries (broken limbs, soreness, exhaustion, poison, wounds) lower speed, endurance, fighting and other skills for several game days (a game day is one real hour). The character can still do suitable work while recovering; temples and healers speed it up. Death by sickness stays rejected (`DESIGN_REJECTED.md`), so poison needs care not to bring it back.
- **[Proposed]** Downed window or recovery chance depends on age and condition.
- **[Proposed]** Logging out in a bed, inn or your own town makes a character **safer** (not invulnerable), while logging out in the wilderness leaves the body exposed. The project owner agreed and noted inns can be abandoned, attacked or burned, with occupants inside.
- **[Proposed]** A "while you were away" report on login, with events resolved by game rules and optionally narrated by the language model.

#### Open questions

- **[Open]** Whether the game warns about the risk of a logout location.
- **[Open]** A grace period for accidental disconnects.

### Remains

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **Remains.** When a character dies they leave a two-dimensional image of themselves, a body with a backpack and all their gear still on it, instead of a tombstone or loot bag. The body decays over time (timeline below).
- **[Decided]** Intelligent creatures may come along, pick up the gear and add it to their hoards. Otherwise it lies where it fell, waiting for someone to pick it up.
- **[Decided]** **Remains timeline (real days).** Remains follow a fixed seven-day timeline, then are cleaned up.
  - **Day 1:** the character falls to the ground and looks like a fresh dead body, as they looked in life. For this first real day **only the owner** (the dead character's player or dynasty) can pick up the gear. That is at least one day of grace to come back for it.
  - **Days 2 to 7:** the body gradually decomposes until it is a skeleton, and slowly sinks into the ground a little, as if the terrain or the sand were absorbing it. From day 2 **anyone** can pick up the gear, and intelligent creatures (goblins, bandits, trolls, dragons) may come along and take it into their hoards. Only intelligent creatures collect gear.
  - **Day 8:** the remains disappear and are cleaned up off the server.
  - **On rock:** where the ground is rock and nothing can sink into it, the remains weather instead. They shrink and fade over the same seven days, getting smaller and harder to see.
- **[Decided]** **Remains must never be lost.** The tombstone problem of other games (remains that fall through the ground or vanish) is a design requirement here. The remains are a server record with a position, not a physics object, and the server checks them:
  - When created, the server finds the surface by looking straight down from the death position, and places the remains on it, even over water's edge or a cliff.
  - Every time the area loads, and when terrain changes under them, the remains are checked and moved back onto the surface if the ground is missing or has changed.
  - The sinking is only a visual offset applied to the model, never to the stored position. The record is never deleted before day 8.
  - The heir's retrieval quest map marks the spot to within about 20 m.
- **[Decided]** **The wizard can retrieve your remains.** At the nearest wizard tower, the town wizard (town mage, Section 8.15) will fetch your remains for a fee.
  - He retrieves everything from every one of your unretrieved dead bodies still in the world, so if you died six times and none has disappeared yet, one visit gathers all six.
  - The gear is delivered to you, and the remains are deleted or marked retrieved on your map.
- **[Decided]** **Party leader retrieval.** If you were the party leader when party members died, the wizard also retrieves the gear of your NPC party members. Another player character in the party has to retrieve their own remains, or hire the wizard themselves. Each player pays for their own retrieval.
- **[Decided]** **Any wizard tower works.** You can use the service at any wizard tower, in any town. Later, some random unaffiliated wizard towers may be placed around the map.
- **[Decided]** **Day 8 cleans up everything on the body.** Gear still on the remains goes with them when they are cleaned up, with no warning notice.
- **[Decided]** **Death marker on the map.** Each set of remains has a marker on the owner's map, such as a skull and crossbones or a tombstone, with a countdown timer showing how long is left before the remains are cleaned up. The marker is deleted or flagged as retrieved when the gear is collected, including by the wizard.

#### Ideas and proposals — not approved

- **[Proposed]** The heir's retrieval quest (above) leads to these remains, so the mechanics line up: a creature that took the gear makes a hoard to raid.
- **[Proposed]** Remains are a flat image facing the player over a mark on the ground. NPC adventurers who die leave remains too, and each tile keeps at most 50 sets, with the oldest turning to bones only. Remains placed by the server at world start (old adventurers, Section 4.13) are scenery and do not follow this timeline.
- **[Proposed]** Details (tunable): the fee is about 10 percent of the value of the gear retrieved, with a minimum of 1 gold, and it is paid before the gear is handed over. The wizard can only fetch gear that is still on the remains: gear already taken by a creature into its hoard stays there. He fetches only your own gear and the gear of the NPCs in your party (see below), never another player's or anyone else's. A town with no wizard tower cannot offer the service, which gives the wizard tower another use (Section 8.15).

### Staying alive

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Design intent: the game tries to keep you from dying, even though the whole world is trying to kill you.
- **[Decided]** Systems let good NPCs rescue a character who has fallen, and let friends save them.

#### Ideas and proposals — not approved

- **[Idea]** In the future, a normal adventuring party is two or three real players plus perhaps one or two NPCs.
- **[Proposed]** The downed state (Section 6.1) is the rescue window. Its length depends on age and condition.
- **[Proposed]** NPC companions use the same traits, skills and memory systems as other NPCs. Their ability to help (carry, drag, heal) depends on their skill and on being nearby.
- **[Proposed]** Rescue comes in layers: party mates and companions first, then nearby well-meaning NPCs or travelers, then town guards and patrols. Death should come from several layers failing, not from one bad moment. After death, the heir's retrieval quest (Section 6.1) is the final layer.
- **[Idea] (brainstorm)** Dynasty is not a die, respawn and run back loop. Characters get many believable chances to survive defeat, serious injury, poisoning, exposure or being stranded. Death stays possible and meaningful but rare, not the usual price of losing a fight; surviving can still cost gear, wealth, time, mobility, trust, reputation and recovery.
- **[Idea] (brainstorm)** Several independent rescue chances overlap: getting yourself out, friends and hired companions, passing hunters, merchants and travelers, hermits and other country folk, guards and patrols, family and town searches, temples and healers, and, very rarely, a kind supernatural being (Section 8.2).
- **[Proposed] (brainstorm)** A quiet server-side **rescue director** checks whether a character has a realistic way to safety, whether help is coming and whether they can make progress, and favors believable encounters (a traveler on that road, a patrol turning up) over teleported help, obvious saviors or secret invulnerability. It stops long helplessness; it does not remove the danger of death.

#### Open questions

- **[Open]** How NPC rescue works in practice: companions only, passersby, or patrols dispatched to a call, and how to stop it from making death meaningless or being farmed.
- **[Open]** Whether NPC companions count toward party size, and what they cost (wages, upkeep).
- **[Open] (brainstorm)** The real risk of permanent death in extreme cases, and when the rescue director should not step in.

### Additional open question

- **[Open]** Whether other players and NPCs can rob or finish a downed character. The suggested answer is that outside PvP zones it is a crime handled by the legal system (Section 9), not a blocked action; inside PvP zones there is no protection (Section 9.0).

### Qualifications and working evidence

- [Absence, duress and notifications](DESIGN_IDEAS.md#absence-and-duress) stay in the source; [inheritance](DESIGN_IDEAS.md#62-what-an-heir-inherits) and [succession](DESIGN_IDEAS.md#67-succession-inheritance-and-the-dynasty) qualify restart and ownership. The [family collection](#children-and-family-growth) retains adoption's proposed successor eligibility.
- [Time conventions](DESIGN_IDEAS.md#71-time-conventions) say remains last eight real days, while the detailed timeline above says cleanup on day eight after seven days. Preserve the discrepancy for source review; do not change durations by inference.
- The [21 Oct death/respawn plan](docs/mirror/items/DEATH_RESPAWN_DESIGN.md) is dated implementation evidence and a backlog, not current built/tested certification. Its wall-clock remains expiry differs from the paused game clock used for aging.
- “Above/below” within preserved passages refers to the original source ordering, available in the source commit. Full paragraphs and their nested exceptions remain intact.
