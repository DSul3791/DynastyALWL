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
- The [21 Oct death/respawn plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/DEATH_RESPAWN_DESIGN.md) is dated implementation evidence and a backlog, not current built/tested certification. Its wall-clock remains expiry differs from the paused game clock used for aging.
- “Above/below” within preserved passages refers to the original source ordering, available in the source commit. Full paragraphs and their nested exceptions remain intact.

## Succession and inheritance

Source: [DESIGN_IDEAS §§6.2 and 6.7](https://github.com/DSul3791/DynastyALWL/blob/dbe793cbcbe04d2207a33e7fd8e2e1edbf266d13/DESIGN_IDEAS.md#62-what-an-heir-inherits), extracted 16 Nov 2026. Recorded decisions remain SOURCE UNVERIFIED, including values described as accepted/tunable. Section numbers and “above/below” refer to the original source ordering.

### What an heir inherits

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** The heir inherits equipment, businesses, properties and bank accounts. The only thing missing is the character's personal skills.
- **[Decided]** Debts pass to heirs along with everything else. A debt that expects a regular payment becomes the heir's obligation, stays on the books and is paid accordingly.
- **[Decided]** **Reputation belongs to the person.** Every player and every NPC has their own reputation score. The dynasty itself has no reputation. Nothing passes between dynasties when they merge.
- **[Decided]** **The dynasty average.** For large loans and purchases, the head of a dynasty also counts the wealth of their dynasty, and everyone under the umbrella (children, stepchildren, spouses) has a reputation that is averaged in. A child who becomes a criminal makes the head and the dynasty look bad. The head's own reputation can be so good that people ignore it, because it is a mean average.
- **[Decided]** When a character retires or dies, the whole dynasty passes to one successor, chosen by the handover chain (Section 6.7). An older child has better skills but less time left to play.
- **[Decided]** Without a will, the handover chain in Section 6.7 applies. Each person in the order may accept or refuse according to their traits and plans, and a will raises the odds of acceptance.
- **[Decided]** The person you play and the owner of the dynasty are the same: the successor.

#### Ideas and proposals — not approved

- **[Proposed]** The dead character's assets pay creditors first, so dying cannot be used to dodge debt. If the estate is worth less than its debts, creditors take what is there and nothing more.
- **[Proposed]** A business's own record carries over, but the heir's personal reputation starts blank (see below).
- **[Proposed]** How to compute it (tunable): the head's standing for credit counts 60 percent, and the average of the other adult members counts 40 percent, plus a wealth bonus for loans. The head's own reputation stays the head's. This number is only used for credit and for how NPCs size up the family, not as a score anyone can see or hold.
- **[Proposed]** Early on an heir leans on NPC employees and managers for skills they lack, and must learn the trade or hire for it.
- **[Idea]** Children learn some skills from their parents as they grow, so when a parent dies the heir is a partially trained character already waiting. The project owner described this as a theory for now.
- **[Idea]** The will names the successor and lists the children with their skills and attributes and leaves the farm or the town to a chosen child. It should be set long before death and can be updated at any time.
- **[Proposed]** For scale: an heir aged 20 has about 21 real months of play left on average, one aged 35 about 13 real months, and one aged 50 about 6 real months.
- **[Proposed]** NPC siblings with greed or resentment might contest a will, and a forged will would use the forgery system. Adult children who have moved away still appear on the list.

#### Open questions

- **[Open]** How large that head start is, and how it works for player heirs compared with NPC children.

### Handover chain (succession)

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Only the chosen successor inherits. The whole dynasty passes to that one person. It does not matter which spouse a child came from, since all are the head's children and all are eligible to be successor at retirement or death.
- **[Decided]** **Retirement is the player's choice, driven by aging.** As a character ages, their skills fall with their physical ability. At some point the player decides it is time to move on, makes sure a successor is chosen, and chooses to retire. This is usually a conversation with a spouse. There is no fixed retirement age.
- **[Decided]** **Retirement.** A character who lives into old age and becomes too old and frail to carry on can choose a successor and retire. The player then takes over the successor's body, and the retired character becomes a senior or elderly NPC who lives out their remaining days on the farm.
- **[Decided]** **Naming a successor can be tested while alive.** Because NPCs talk through the language model, a player can say to a child, stepchild or spouse, "I am thinking of making you my successor", and they answer as themselves: proud, nervous, or unwilling. Naming someone does not bind them. They can still decline when the handover comes.
- **[Decided]** **The handover chain (order of succession).** When the dynasty is handed on (death or retirement), the named successor, if any, is asked first. If there is none, or they decline, the offer goes down this line, and each person in turn accepts or declines. A spouse always comes after her own children:
  1. All of the player's own blood children, grouped together and taken oldest to youngest, whichever spouse they came from. (Five children with the first wife and two with the second are one group of seven, by age.)
  2. The first spouse, if able. An elderly or dead spouse cannot take it.
  3. The second spouse's children from before (the player's stepchildren), oldest to youngest, then the second spouse.
  4. The third spouse's stepchildren, then the third spouse, and so on in the order the spouses were married.
  If the first spouse has children of her own from before, they come between the blood children and her. Whoever takes it becomes the player's character.
- **[Decided]** **Each person in line chooses; with no will, the chain is the order of asking.** The chain is the order in which the offer is presented. Each person in turn may accept or refuse, and a refusal passes it to the next in line. With no will, nobody is named, so the offer simply goes down the chain.
- **[Decided]** **A will raises the odds, but is never a certainty.**
  - If a successor is named, the chance they accept is much higher.
  - It is not 100% just because it is a parent's will. It is certain only if the successor agreed beforehand.
  - If a child told the parent they truly do not want it and is named anyway, the chance of accepting rises by about 50%, so it becomes a coin flip. If they refuse, it passes to the next in line.
  - **Character attributes decide the odds.** Loyalty, a sense of duty and greed each push toward accepting, so most people will accept. There is always some chance they will not.
  - The one exception is the last in line, who must accept (above).
- **[Decided]** **The last in line must accept.** If the offer goes all the way down the chain and everyone has declined or is dead, the last person on the line, which is the youngest child (not the last spouse), accepts no matter what. A player who has built any lineage always keeps their dynasty.
- **[Decided]** So it pays a character to spend time encouraging the children to want to be the successor (conversation, teaching and the markers in Section 6.6).
- **[Decided]** Siblings who are not the successor stay in the household and age out over time, unless they leave (see below).

### Inheritance from an unknown benefactor

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **No lineage at all: the mysterious will.** If the player has no dynasty or lineage left, they roll a new character, who receives the whole dynasty through a mysterious will from a stranger. The server charges the inheritance tax below on it.
- **[Decided]** **Inheritance tax applies only to a will from an unknown benefactor, is money only, and the player chooses what to sell.** An heir from the family chain (above) pays no inheritance tax.
  - The tax is always money and must be paid before the character can play.
  - If the inheritance has too little gold, the character can pick which common items to sell from a screen (see the bankruptcy rule below). It is their choice first.
  - **The server never takes items.** Nothing is taken away from anyone: not hard-won gear, boss drops, bought cosmetics, or anything they enjoy. Only money is ever asked for, and only common items can be sold to raise it.
  - **Dying poor:** if there is not enough to sell without losing their best things, the player may borrow from the nearest town to cover the tax. (The temple's reputation discount is described below.)
- **[Decided]** **The tax size depends on the benefactor's reputation.**
  - The town and the temple both know who the benefactor was, and the benefactor's reputation with each decides how large a discount the new character gets.
  - A benefactor with a very high reputation with both could leave a tax of one gold, payable on inheriting.
- **[Decided]** **The tax starts around 40%.** The base rate for a benefactor with no reputation is about 40% of the money and sellable assets inherited. The better the benefactor's reputation with the town and the temple, the lower it goes, down to a fee of 1 gold. The aim is to give the new character everything if the benefactor was well regarded, and not to take it all when they were not. The 1 gold is a delivery fee for getting the dynasty to the starter town.
- **[Decided]** **The tax amount.** The tax is 40% of the inheritance at no reputation, or 1 gold, whichever is higher, and limited to what is available in the inheritance.
- **[Decided]** **Bankruptcy rule: only common items can be forced.**
  - If the inheritance has no gold, or not enough, the new character can be made to sell common items (all basic items) to raise the tax.
  - Anything magical, or bought from an event (costumes, cosmetics, special gear), cannot be forced out of them. Once the common items are sold, that money is all that can be taken. The tax is paid from it and the rest stays.
  - **Example:** a normal sword, an iron sword and a cheap leather suit of armor can be sold. A really nice suit of armor, a magical sword and a couple of bought costumes cannot. These stay where the dead player stored them. If they were in a house, they are still in that house, waiting for the new character.
- **[Decided]** **Order of forced sale.**
  - Always take the least valuable things first, starting with common items.
  - Magic items, costumes and event-bought items can never be forced.
  - Houses, businesses and other property can be forced to sell only when there are not enough other assets to cover the debt. In that case the player is given the choice: sell the property, or take out a loan from the town and pay it back.
  - Loans have terms measured in game time.
- **[Decided]** **Gift items are not safe if the other assets fall short.** Items named in the will can be sold for the tax when there is nothing else to cover it, under the same least-valuable-first order. Magic, costume and event items are still never forced.
- **[Decided]** **The new character may ask for a loan.** If they wish, they can take a loan from the town to cover the tax and to keep all of the items. The interest rate depends on their new reputation.
- **[Decided]** **Loan rate numbers (accepted; to be tested and tuned).** From 4% per game year for a new character with a high reputation up to 16% for one with a low reputation, and higher again for a character whose benefactor was hated. The loan can be renegotiated as their reputation grows.
- **[Decided]** **Items left to the new character in the will.** The will can name which items go to the new character on creation. For example: "leave my magic equipment in storage where it is, but give my iron sword, my iron pickaxe and my horse Ajax to the new player to get started." On creation, the tax is taken first, then the named sword, pickaxe and horse are handed over with a "good luck, adventurer".
- **[Decided]** **A will can carry its own tax money.** A player who writes a will will usually set aside gold with it to cover the inheritance tax, for example 100 gold, and the tax is taken from that gold. The tax relates to the size of the dynasty (money, worth, number of buildings and so on), and the writer's reputation with the town lowers it, so the successor gets what was left to them.
- **[Decided]** **The discount splits 50-50.** The benefactor's town reputation can remove half of the 40% and the temple reputation the other half. The figures are tunable.
- **[Decided]** **Where the next character starts.**
  - When the dynasty passes to a successor for any reason, the player restarts automatically wherever that successor is.
  - With no successor, a starter town picker pops up. It suggests the nearest town where they own property (a home or apartment), or the nearest town if they own none, and the player may choose another.
- **[Decided]** **An early character who dies with nothing.** If a young character is killed out adventuring with no will and no successor, and owns only a couple of simple tools, the town and the temple take pity. They keep their basic tools and equipment. They owe the 1 gold fee as a debt, and their first adventure can be to gather materials worth about one gold piece to pay it off.
- **[Decided]** **No will and no dynasty at all.** The equipment the dead character has on them is handed over automatically to the next character, who owes 1 gold to the town where they spawn.
- **[Decided]** **The benefactor's reputation passes on in part.**
  - Wherever the benefactor had a reputation, the new character gains some of it as word spreads in the town. People respect the benefactor and pass some of that respect on.
  - NPCs could offer condolences, offer to show the new character around town, find them work, or help on the farm, because they speak highly of the benefactor.
  - **Residency:** to be accepted as a resident, a character needs enough reputation. If the benefactor was a resident of that town, the new character is automatically set to the minimum required reputation. If the benefactor stood higher, the new character also gains a percentage of the excess.
  - **A bad benefactor:** with a terribly low reputation the opposite happens. The tax goes up, and the new character may lack the reputation to live in the town. They may be forced to sell the property, or take a loan at an elevated interest rate until they can renegotiate it on their own reputation.
- **[Decided]** **Starting numbers for passed-on reputation (accepted; to be tested and tuned).**
  - In a town where the benefactor was a resident: the new character is set to the residency minimum plus 25% of the benefactor's reputation above that minimum.
  - In a town where the benefactor was known but not a resident: 10% of the benefactor's reputation there.
  - The same rule applies to the temple.

### Merging dynasties and households

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** A person has only one dynasty. Taking over another dynasty (purchase, marriage, rescue) merges the two by combining the entire families. Everyone comes in under the player: the player gains a new spouse or spouses and stepchildren, and all the properties, businesses, debts and everything else that goes with the dynasty.
- **[Decided]** A dynasty may have several spouses over time. They die off from age or sickness, and each adds assets and holdings to the dynasty.
- **[Decided]** **Duress ends with the merge.** When a player buys or takes over a dynasty and merges it into theirs, the duress on the absorbed dynasty ceases to exist, because it was caused by its previous player not logging in and playing. The buyer takes on no duress from it. Duress stays one value per dynasty, so merging never multiplies the upkeep.
- **[Decided]** Dynasties transfer inside the game by marriage, adoption, will, or sale to a successor. The login itself is not sold, so identity, reputation and record stay with the person.
- **[Decided]** **Households have no hard cap; cost is the limit.** Each member needs a bed, food and some care, so a big household is an expense, and extra people sleep in tents or at the inn if the house is full. Household size does not change duress. As a backstop for server load, marriage and adoption pause once a dynasty has about 40 living members.
- **[Decided]** A dynasty can have many living spouses at once. The aim is to grow a dynasty as in medieval times and plan against sickness and age. Spouses are people who help run the day-to-day work of the dynasty and household and help raise children.

### Check-in and automation

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **The check-in needs a real action.** To count, the player must log in and do something: talk to someone, buy something in a shop, go on an adventure, pick a crop, feed an animal, or anything else that shows they really did something. The action should also work as robot detection, so a bot that runs in circles or runs into a wall does not count.

#### Ideas and proposals — not approved

- **[Proposed]** Bots and client automation are banned in the terms of service. Hands-off play via NPC staff is allowed by design, and the household economy already pays less for neglect (Section 6.6).
- **[Proposed]** How to build it: only actions that change the world and are checked by the server count (an item bought or harvested, a conversation completed, a task finished). Movement alone never counts, and the same action repeated within a minute counts once.

#### Open questions

- **[Open]** The list of qualifying actions, and how many different kinds are needed.

### Source-review questions and dependencies

- The recorded offer chain and its “youngest child, not the last spouse” forced-acceptance exception must both remain visible; their exact ordering needs source reconciliation. Adoption eligibility remains a [proposal in the family collection](#children-and-family-growth).
- Naming someone is recorded as nonbinding, while prior agreement is described as making acceptance certain. Preserve both qualifications pending source review.
- Keep the distinct benefactor-only tax, protected-item rules, forced-property-sale/loan choice, tax cap, reputation discounts and transferred reputation together. No single rate or “nothing is taken” summary replaces their nested exceptions.
- [Death and rescue](#death-and-rescue), [aging](#aging-and-lifespan), [personal finance](DESIGN_IDEAS.md#63-personal-finances), [duress](DESIGN_IDEAS.md#absence-and-duress) and [NPC memory](DESIGN_IDEAS.md#88-npc-character-memory-and-conversation) remain dependencies. Individual reputation versus dynasty credit averages is a distinction, not permission to invent a dynasty-wide reputation score.

## NPC population and migration

Source: [DESIGN_IDEAS §§8.2–8.3](https://github.com/DSul3791/DynastyALWL/blob/61cba95e7f41c0aa2528820835844f637262103b/DESIGN_IDEAS.md#82-npc-population), extracted 16 Nov 2026. Recorded decisions remain SOURCE UNVERIFIED; complete paragraphs, examples and original tags are preserved. Internal section numbers refer to DESIGN_IDEAS.

### Population, roles and country folk

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Population is controlled by aging, sickness, poverty and murder.
- **[Decided]** New NPCs spawn at about age 20. If two single NPCs live and work together they may marry and have children. Children start small and stay near or within a reasonable distance of their parents. They grow up with skills and temperament similar to their parents.
- **[Decided]** When a player builds a job building (for example a blacksmith blueprint), an NPC may come along and apply. The server rolls up a new NPC for that role (see "Role-weighted rolls" below) and places them in the world.
- **[Decided]** NPCs start at level 1 and simple. Over time they build stories, history, skills and fortitude. They can gain or lose wealth.
- **[Decided]** NPCs have core traits: goodness, lawfulness, physicalness, dexterity, wisdom, intelligence, charisma, and others. They also have skills like players.
- **[Decided]** **Role-weighted rolls.** NPCs are never rolled with flat random traits and skills. Every role (blacksmith, guard, scavenger, farmer and so on) has a **template** of weighted traits and skills that fit the job, and each NPC is rolled with **variance** around that template. A blacksmith comes out with blacksmith-shaped skills and traits, even if he is a weak one. A guard comes out "guardly", weighted toward physicalness and a sense of duty or lawfulness. Variance still makes individuals differ: a poor blacksmith is still weighted toward smithing, not a random mix. This applies to all NPC generation, including scavengers, the NPCs who apply to job buildings, orphans and displaced arrivals.
- **[Decided]** NPC memory tries to remember everything but forgets over time, like a human.
- **[Decided]** NPCs are the main story drivers, offering work and adventure to players.
- **[Decided]** Players can converse with any NPC. Conversations are handled by a **language model**.
- **[Decided]** Language model use follows the budget in Section 3: conversation with players and occasional judgment calls use the model, and routine NPC work runs on rules.
- **[Decided]** The project owner intends to run a language model on their own Ubuntu machine as the game's AI source, and to add hardware as the game grows.
- **[Decided]** **Scavengers (roaming pickers).** Some NPCs roam certain areas and live off the land. If one finds an unclaimed item on the ground (a dropped sword, discarded nails or iron), they pick it up and sell it at a reduced price to the nearest fitting tradesperson, such as scrap metal to the blacksmith, like a pawn shop. Picking up unclaimed goods is not a crime.
  - They use the ordinary NPC traits (honesty, lawfulness, goodness and the rest; Section 8.8), rolled from a scavenger template with variance (role-weighted rolls, above), not a separate system. The template is mostly low-to-middling skills with a wide spread in honesty and boldness. Most are harmless and take only what lies around. A bold, low-honesty one might steal from a player's person, and then it is a thief and the law system applies (Section 9); fencing stolen goods uses the existing fencing and stolen-goods economy.
  - Players cannot tell which kind they met from the archetype alone. A scruffy one may turn out to be honest and kind, and worth befriending, and another may be genuinely sketchy. It is found out through talking and watching, as with any NPC.
  - Details (how many, where they roam, how much they pay) are tunable.

#### Ideas and proposals — not approved

- **[Proposed]** Keep personality (goodness, lawfulness) conceptually separate from abilities (physicalness, dexterity, wisdom, intelligence, charisma). Personality drives choices, abilities decide whether choices succeed.
- **[Proposed]** Each memory stores a strength, an importance and a timestamp. Decay is computed only when the NPC recalls it, and recall reinforces it. Importance slows fading. Strongest relevant memories plus traits form the context for a conversation.
- **[Proposed]** Tools such as Ollama and llama.cpp run open-weight models on Ubuntu, and vLLM is built for serving many requests at once. Calls cost nothing per use, but hardware, power and capacity are real limits, and a small model is weaker than large hosted ones, so prompts should be tight and outputs structured and validated.
- **[Proposed]** Check each model's license before building a paid game on it. Some open-weight licenses restrict commercial use.
- **[Proposed]** If the model is busy or offline, NPCs fall back to rules or simple dialogue and the game keeps working.
- **[Proposed]** NPC population caps per island or region.
- **[Idea] (brainstorm)** **Country folk.** Forests and roads around towns hold believable residents with territory, livelihoods and habits, and every shade of good, selfish, neutral and secretive: hermits, hunters, trappers, herbalists, scavengers (above), charcoal burners, wanderers. Some watch the player unseen. A secretive hermit may witness an attack and then rescue the player, report the danger, hide, or scavenge the aftermath, by personality and risk. They do not give away their home or what they know; getting to know locals can uncover secret homes, routes, rare plants or witnesses. Perhaps only the town wizard knows who the hermit is, and everyone else thinks it is a ghost.
- **[Proposed] (brainstorm)** Track these people as short timestamped observations and work out important memories only when they matter, rather than running conversations for distant NPCs.
- **[Idea] (brainstorm)** **Real supernatural beings.** Some mysterious rescuers are ordinary people; some really are ghosts, bog witches or other beings, and the player should not always know which. A cottage may seem real and then vanish behind you; the same figure or dwelling may turn up in different places within its region. The being and its territory persist while its visible form (cottage, campfire, figure, lights) comes and goes. Spirits may be kind, neutral, deceptive or dangerous, may attach to a dynasty and remember it across generations, and may become a family legend passed on by journals and stories, not inherited memory.
- **[Idea] (brainstorm)** A kind apparition is an extraordinary last resort, only when self-rescue, companions, travelers and guards cannot get the player safe in reasonable time. It is not the normal rescue.
- **[Idea]** NPC merchants eventually appear on their own. They need somewhere to live and somewhere to work, so they only appear where a profitable opportunity (a price gap and a connecting road) coincides with available housing and workspace.

#### Open questions

- **[Open]** The templates themselves (which weights and how much variance for each role) are designed per role as the roles are built.
- **[Open] (brainstorm)** How rare supernatural events are, what triggers them, whether the being is physically real, and whether misread events or hallucinations can produce the same stories.

### Displacement and migration

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** When a town falls, displaced NPCs migrate toward the nearest town, with some randomness (sometimes the second nearest).
- **[Decided]** On arrival they look for work they are good at, may take a new job, may build a house or inn if wealthy enough, or may become bandits or join a traveling circus or bandit group.

#### Ideas and proposals — not approved

- **[Proposed]** Choices are weighted random, with traits shifting the weights.
- **[Proposed]** Travel is abstract when no player is near (departure time plus travel time), using wrap-aware distances.

#### Open questions

- **[Open]** Whether NPCs can cross the ocean on their own. If not, islands are separate populations unless ships connect them.

### Dependencies and source-review questions

- [Aging](#aging-and-lifespan) retains the differing NPC starting-age range; neither version is silently replaced. [Children/family](#children-and-family-growth) distinguishes player-household pregnancy choices from NPC-population behavior.
- [Memory and conversation](DESIGN_IDEAS.md#88-npc-character-memory-and-conversation) and [language hosting](DESIGN_IDEAS.md#89-language-service-hosting) retain their detailed designs. Model/host examples above are historical proposals, not current product or licensing recommendations.
- [Death and rescue](#death-and-rescue) retains rare rescue qualifications; [duress](DESIGN_IDEAS.md#absence-and-duress) and settlement decline describe different causes of displacement. Player major-illness exclusions remain in [§8.1](DESIGN_IDEAS.md#81-towns).
- [NPC technical plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/NPC_DESIGN.md) and [first-island roster](TOWN_NPC_SPEC.md) are dated records with proposals, not current population censuses or blanket implementation evidence.

## Property and town management

Source: [DESIGN_IDEAS §§8.4–8.6, 8.14–8.16](https://github.com/DSul3791/DynastyALWL/blob/7311ee19374bdb5f0d369e92aee25db11f365e42/DESIGN_IDEAS.md#84-town-planning-and-the-civil-engineer), extracted 16 Nov 2026. Legacy decisions remain SOURCE UNVERIFIED. Complete nested rules and original tags are retained; section numbers refer to DESIGN_IDEAS.

### Town planning and the civil engineer

#### Ideas and proposals — not approved

- **[Idea]** Eventually, both AI and player characters can build and work on towns. A town owner could hire a civil engineer.
- **[Idea]** The engineer organizes town ideas and suggests routes for roads, areas for farmland, and how to lay out the town, with a little randomness.
- **[Idea]** In the town control panel the owner reviews the plans and approves or denies them. The engineer's job is to keep improving the town. Once a plan is approved the engineer arranges builders to start on houses, buildings and roads, in the style of the old Warcraft-type games.
- **[Proposed]** A plan is a data object (zones, road routes, field areas, building footprints) generated by an algorithm from terrain data (slope, water, soil, resources, existing buildings), with a seed for variety. The control panel shows it as an overlay, lets the owner approve or deny the whole plan or single items, and shows cost and time estimates.
- **[Proposed]** Approved items become jobs for NPC builders and use the same blueprint placement, leveling checks and material delivery as player building (Section 10.1).
- **[Proposed]** The engineer's skill and traits affect plan quality. The language model can explain a proposal in conversation, but placement and numbers come from the planner, following the rule that the game owns the facts.
- **[Proposed]** Planning runs in phases that each need approval: survey, district and wall plan, road plan and road building, then building lots. Each suggestion carries its reason ("flat, near the river, downwind of the tannery"), which the language model can phrase but the planner's numbers decide.
- **[Proposed]** The planner needs cheap terrain queries: slope, fertility, water access and resource proximity. Consider baking coarse land-suitability layers per region so the planner does not scan voxels at runtime. This has not been checked against the data the generator already produces.
- **[Idea]** When the planner is told to build something, it orders workers to use supplies from the town warehouse. Wood can come from local mills or another town, stone from the town's own mines or elsewhere for fancy stone, and metal the same way.
- **[Idea]** **The road builder.** A separate tool from the town planner, pointed at the whole map instead of one town (see "Road, mine and tunnel builders", Section 8.17). The player picks two points; the builder proposes the best route, favoring the shortest or shallowest water crossings and choosing where bridges go. The player reviews and approves it (the same "planner proposes, player approves" pattern as above). Then it does the ground work itself, levelling, averaging and smoothing the terrain with the same checks as blueprint placement (Section 10.1), and lays the chosen surface (a rough wagon path, a dirt road, cobblestone). Road condition and wear follow Section 8.13.

#### Open questions

- **[Open]** Whether plans can run unattended (for example auto-approval within a budget), how often the engineer proposes, and how plans account for existing player buildings and claims.

### Town roles and management

#### Ideas and proposals — not approved

- **[Idea]** Players in a friends group (Section 6.13) can give each other rights in a town. A friend could be a town overseer with the right to hire, fire and manage NPCs.
- **[Idea]** Access comes in roles. Some people have full access. Others only oversee land sales, handle the guards and militia, manage tradespeople, approve road building, approve buildings and construction, or control the warehouse.
- **[Idea]** A town can have an NPC town manager with their own building. If there is no manager, the notices land on the owner's desk, because the owner is the town manager.
- **[Idea]** Later, a town can hire an AI trade manager with their own little building, who works with the warehouse, shippers and merchant NPCs to move goods. The player can visit to see their settings and history. At first this is done by hand.
- **[Proposed]** Rights are a list of named permissions, and roles are bundles of them. The owner has everything and can create custom roles.
- **[Proposed]** An action log records who approved, hired or sold what, which prevents arguments between friends.

### Land and property

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Starter towns have houses and farmland for sale. A player who buys one can work the land and live on the starter island.
- **[Decided]** A home whose owner vacates is eventually deemed **abandoned** once enough time passes, and returns to the market.
- **[Decided]** A remarrying spouse can take over a ruined dynasty's property by paying the town its back taxes and bills (Section 6). If nobody does within the window, the town claims it.
- **[Decided]** A property owner who has gone long enough that their dynasty reverts to NPC (Section 6, duress) loses the property to the town: it appears on the town manager's screen and the town may claim the houses, businesses, farmland, mines and other resource sources. For a mine, the town pays for repairs before letting it collapse (Section 11.2).
- **[Decided]** **When a home is abandoned.** If a home's rent or bills go unpaid for **two game months**, it is deemed abandoned and returns to the market. The owner gets a **notice after the first game month** of non-payment. A game month is about 30 real hours, so the whole thing is roughly 60 real hours (2.5 real days). Bills are paid automatically from the dynasty's banked funds, even while the player is offline, so it is the player's responsibility to keep enough money banked to cover bills during absences (see duress and receivership, Section 6.1).
- **[Decided]** **Furnished or empty.** When an abandoned house goes up for sale, the buyer chooses: buy it **furnished** at full price, with the previous owner's belongings and stored goods still inside, or buy it **empty** at a reduced price. If the buyer takes it empty, the old belongings simply disappear. They are not stored anywhere for anyone to claim later.
- **[Decided]** Players can own houses, businesses and farmland in any town, several in one town or spread across towns, as long as each town accepts their reputation.
- **[Decided]** Players can also prospect their own land in the wilds and mark it with a **town stone** (to found a town, within the spacing rules in Section 8.17) or a **homestead marker** (a private home, Section 8.17).
- **[Decided]** Owning property in an enemy town is hard. Someone who owned property in two towns before they became enemies keeps it, but tensions can get weird and their loyalty, and so their reputation, may come into question in both.
- **[Decided]** A town is basically a group of friends, and the town owner sets its rules. Residents are already vetted because they are already in the town.
- **[Decided]** Buying into a town: players whose reputation with the town is at or above a score the owner sets are accepted automatically. Players below it must be approved, and meanwhile can stay at the inn.
- **[Decided]** Players below the score can earn their way in: work around town, adventures and quests for the town, and acts of kindness such as hunting and donating the food to the local temple or inn, ridding the area of bandits or goblins, or volunteering at the well or wherever help is needed. Once their reputation reaches the score they are accepted automatically.
- **[Decided]** The town owner can whitelist or blacklist players by **account**, not just by character name, so a banned player cannot come back as a new character.
- **[Decided]** Good deeds raise reputation mainly with the town that benefits, and a little with its allies once the news spreads. NPCs who witness or benefit from a deed remember it (Section 8.8).
- **[Decided]** Repeating the same deed counts for less each time, so reputation cannot be farmed (donating rabbits all day). The reduction cools down gradually, though: someone who keeps doing good deeds regularly over time, out of the goodness of their heart, earns a reputation as a good person rather than being penalized.
- **[Decided]** Roughly half of the reputation from a deed is permanent and half is temporary. The temporary half fades slowly (over about a real week) as people forget, so reputation drifts down unless it is kept up.
- **[Decided]** Reputation timing uses real days, so a deed lasts long enough for a weekly player to benefit.
- **[Decided]** Some deeds are never forgotten: epic quests, saving someone's life and the like. They become stories the village tells. The story starts with the person helped (whoever gave the quest, whoever was saved), who tells their closest friends; they tell theirs, and before long the whole town knows. Each teller passes it on through their own memory and honesty traits (Section 8.8), so the story changes a few times along the way, embellished, shrunk or muddled.

#### Ideas and proposals — not approved

- **[Idea]** Before building a home in a town, a player buys a plot of land or a building that is for sale: a house or a business. Someone might buy the smithy to be the blacksmith, or own it and have an NPC run it.
- **[Idea]** Owners pay taxes on the lot or the business. If a player pays business taxes, it is in the town's interest to help them succeed.
- **[Idea]** A player can buy a farm outside the walls and build a house, barns, sheds and fields on their own property as they like.
- **[Idea]** A player can own several properties and build an empire over time: live on the farm, own the smithy and the bakery, with the spouse working one, a child or hireling running another, and children and hirelings working the farm.
- **[Idea]** A player might live in a town run by the server (if those exist later), in another player's town, or in their own.
- **[Proposed]** When two towns turn hostile, owners in both get a warning and a choice: keep both and accept the standing loss, or sell one.
- **[Proposed]** A legendary deed is one story record (who, what, where, when, the facts) plus, per NPC who has heard it, their version: how strongly they remember it, which details they changed and who told them. Spreading follows each NPC's social ties, a step every so often in game time, with talkative and social NPCs passing it on faster. Reputation from such a deed is permanent and does not need the teller to remember the details right. Travelers and wagons carry it on to other towns through the news system (Section 13.6). When a player asks an NPC about it, the language model voices that NPC's version, so different villagers tell it differently.
- **[Proposed]** One way to do this: each kind of deed has a "recent count" that decays a little every day; a deed's value is divided by (1 + recent count), so a burst of the same deed quickly stops paying but the same deed once a day or so keeps paying almost full value. A steady habit over weeks (for example, a donation most days for a month) adds a lasting "known for good deeds" bonus. The temporary half of each gain fades linearly over seven real days; the numbers live in a tunable table.

### Contesting a town claim

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** A town must have real things in it to be feasible. Someone who claims several towns and travels away needs managers and guards to hold each one.
- **[Decided]** Anyone can make an offer to buy any town at any time by talking to its town manager. The manager sends a notification to the owner that an offer has been made, with a recommendation: for example, whether it is in good faith and what the manager thinks the town could fetch in currency or resources.
- **[Decided]** The owner accepts, negotiates or declines. An accepted offer transfers the town at once. A good offer also gives owners a way to retire wealthy.
- **[Decided]** **Presence keeps a claim safe (modelled on Atlas).**
  - A town marker is safe as long as the owner, or a real member of their friends group (Section 6.13), is inside the reserved zone.
  - When no real player is inside the zone, a 24-real-hour timer starts counting down. Anyone from the owner's friends group entering the zone stops and resets it.
- **[Decided]** **Buying a claim during the timer.**
  - While the timer runs, a player who tries to place a claim there is told that a claim already exists and asked if they want to request to buy it.
  - If they do, the owner gets a notification. The challenger makes an offer, and the owner can accept, decline or counter-offer.
  - Declining does not stop the timer.
- **[Decided]** **The 24-real-hour takeover.**
  - If the timer runs out with nobody back inside the zone, the challenger can start a 24-real-hour hostile takeover.
  - The owner or anyone in their friends group can stop it, and reset the countdown, just by logging in and being inside the zone.
- **[Decided]** **Paid guards make a town safe from hostile takeover.**
  - Hostile takeover is only possible before guards have been established on the property.
  - Once there are guards on the property and their wages are paid, the town is safe from hostile takeover and from griefing.
  - The guards keep being paid, and keep the town safe, as long as there is game currency in the owner's dynasty or the town's coffers.
- **[Decided]** **No extra grace for new claims.** Every claim, new or old, has the same two rounds of 24-real-hour protection: 48 real hours to get back inside the claim. A player who places a marker must log back in within two real days. Before placing a claim, a player should have two NPCs to assign as guards and enough money to pay their first wages (Section 8.18), and should earn it by trading at the starter town or another town.
  - The shape of the zone is not settled.
- **[Decided]** When a hostile takeover succeeds, the challenger pays the previous owner a fixed amount based on the town's value (or its rubble if it is a ruin).
- **[Decided]** A town that does nothing productive but still has a manager, clean water, a temple and guards is an expense on the owner's other towns or dynasty, so hoarding idle towns costs money.
- **[Decided]** Paid guards protect a town from hostile takeover (see above). Guards who go unpaid leave, which removes the protection and ties it to the town's money.
- **[Decided]** All claim windows are in real time. How the owner hears of an offer or a challenge depends on whether the town has a manager (Section 8.15).

#### Ideas and proposals — not approved

- **[Proposed]** **Suggested details (tunable).**
  - The zone that counts for presence is the town's current circle of influence (150 m for a new camp), not the whole reserved area, otherwise someone 1.4 km away would hold the claim.
  - Guards: at least 2, and 1 per 25 residents as the town grows. If the coffers cannot pay, the guards give notice for one game month (about 30 real hours, so a game-time rule) before leaving. Protection ends when they leave, and the timers can start.
- **[Proposed]** The price is the rubble value of the buildings (the bill of materials minus degradation) plus the unpaid wages and debts the new owner takes on. The server works it out from the town ledger, with no negotiation.

#### Open questions

- **[Open]** Whether walls add anything now, what happens to buildings, NPCs and debts when the owner changes, and (separately) the shape of the zone.

### Managers, remote control, word and safe towns

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** A town with no manager has nobody to deliver word to the owner. There is no notification. If the owner is in the area, a visitor can see that and make an offer at the block. If the owner is away, a challenger simply puts in a claim, and if the owner does not return within the 48 real hours of protection (Section 8.14), the challenger gets the town.
- **[Decided]** The town stays on the former owner's ledger until the next time they visit it, because they still believe they own it. On arrival they find it is owned by someone else, and it drops from the ledger.
- **[Decided]** This is a deliberate exception to the legibility principle (Section 3): not knowing about a loss until you return is part of the cost of leaving a town unmanaged. A town with a manager has no such gap, since the manager sends word.
- **[Decided]** Without a manager, the owner must be physically at the town's office to change anything, give commands or read the town's books and interface.
- **[Decided]** With a manager, the owner can control the town remotely through the manager, and the manager makes certain decisions while the owner is away. The owner sets which decisions the manager may make.
- **[Decided]** The manager makes two kinds of decisions: ones he can make automatically, and ones where he must request approval or give the owner options to choose from.
- **[Decided]** A town is unsafe, a gray area, until it is established. A camp becomes established when two NPC guards are assigned to it; a larger claim, when it has a town manager building and a guard building and the first round of guard wages is paid (Section 8.18). Once established it is a PvE area, unless it lies inside a PvP zone (Section 9.0).
- **[Decided]** In a PvE area people can make offers and visit, but they cannot hurt anything. Nobody can raise an army and attack the town. Players who cross into a PvE area can no longer attack anyone.
- **[Decided]** Inside a PvP zone there is no established status and no protection: no PvE rules, no guard protection from takeover, no safe towns (Section 9.0).
- **[Decided]** In an established town, word can travel by carrier pigeon or by magic (this is a fantasy game). A town can have a pigeon tower or a wizard tower, run by the pigeon master or the town mage (see the tiers below). A message goes to the nearest tower or mage, then onward to the recipient.
- **[Decided]** Delay depends on distance: how long a pigeon flies, or how long magic takes to reach the nearest mage or tower and then the recipient.
- **[Decided]** Matters of the whole dynasty use real-time messaging in the app. In-world mail and delay cover town business at a distance, such as an offer on a town.
- **[Decided]** When someone makes an offer on a remotely controlled town, the owner is told that they will be notified in a stated number of hours or days, based on the delay for word to arrive. The offer then stands for a time.
- **[Decided]** How long an offer stands is the offerer's choice: a set period (for example a real week, since players must have time to log in) or a permanent standing offer. The time between offer and answer is expected, because communication takes time.
- **[Decided]** Communication improves in tiers, in line with the early-to-late quality ladder (Section 11.1):
  1. Early: a rider on horseback, or a message carried by ship. Slow, and it can fail or be delayed.
  2. Next: a **pigeon master** with coops, a building and a business. Faster over the local region.
  3. Later: a **wizard tower** with a town wizard (also called the town mage or high mage). Enchanted pigeons work with ordinary pigeon masters and coops but fly much faster, about 10 to 100 times the speed of a normal pigeon (the exact figure is to be tuned). The recipient can write a reply and send it back on the same pigeon, which then returns.
- **[Decided]** The role names are pigeon master for the coops and town mage (or high mage) for the wizard tower.
- **[Decided]** **Real-world alerts follow the in-world delay.** An email or app alert about a claim (a request to buy, a timer starting) is sent only when the in-world message would have reached the player. If the player is logged out in the town, the alert is instant. If they are in another town or away on an adventure, it waits as long as the message would take to reach them. With a pigeon tower, that is a pigeon's flight time over the distance; with a wizard tower and a pigeon tower the pigeons are enchanted and much faster. Without a manager there is no notification at all. Hostile claims are not possible while the town has paid guards (Section 8.14), except in PvP zones.

#### Ideas and proposals — not approved

- **[Proposed]** Word delivery uses a message system with distance delay and a carrier type (courier on horseback, pigeon, ship, later enchanted pigeon). Pigeons and couriers can fail or be intercepted. A manager can send word to the owner this way. This is separate from the real-world email notifications for the player's account (Section 6), which exist for duress and receivership.
- **[Proposed]** A standing offer does not lock the offerer's money. Funds are checked when the owner accepts, and an offer that cannot be paid fails with a reputation cost. A short offer could instead hold the money in escrow.
- **[Idea]** The wizard handles many roles, not just mail: solving problems around the town, defence of the town (a magical shielding dome, fighting from the ramparts during goblin or bandit attacks or a hill giant coming to ravage the town), and day-to-day research that improves the town's technology and its communication with neighbours.

#### Open questions

- **[Open]** What a wizard tower costs, what the wizard's research actually unlocks, how strong the defence is against each threat, and the limits that keep one wizard from solving everything (for example a cost, a cool-down, or a single point of failure if the wizard is lost or hostile).
- **[Open]** The cost of sending word, whether a standing offer needs a refresh or can be cancelled any time, and the delay formula.
- **[Open]** What the manager can decide automatically.

### Buying a server-owned town

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** If a town owner's dynasty falls into receivership, the town is part of what can be taken over. If nobody takes it, it reverts to the server and an administrator owns it.
- **[Decided]** A server-owned town goes on a list that players can apply to buy. The price depends on the town's size, its population, its wealth and how long it has been without an owner. It is treated like a normal business: the buyer inherits a low-spirit town and also gets its potential for great wealth.
- **[Decided]** The exact price formula is worked out later, from the town's real value and its earning potential.
- **[Decided]** A town's price falls the longer it stays server-owned, because its value falls as money runs out, buildings decay and people leave (Section 8.13).
- **[Decided]** To apply, a buyer goes to the nearest town (which can be the town itself) and talks to the town manager, an NPC at this stage. The manager talks about the town's problems and says it is available if someone good enough can be found. The buyer negotiates with the manager. If the language model judges the negotiation to be in good faith, they reach an agreement. This must happen before the town falls apart.

#### Open questions

- **[Open]** The price formula, how competing applicants are handled, and what the manager's good-faith judgment looks at.

### Qualifications and dependencies

- Preserve the distinction between property abandonment for unpaid bills, dynasty receivership, town decline and hostile claim windows. Their game-time/real-time clocks and notices are not interchangeable.
- The unmanaged-town notification gap is an explicit recorded exception; real-world claim alerts follow in-world message delays. Dynasty duress alerts are a separate system.
- Established PvE protection, paid-guard claim protection and PvP-zone exceptions remain distinct. Do not collapse “cannot hurt anything” into immunity from every environmental/NPC threat; [death/rescue](#death-and-rescue) and the wider zone rules remain relevant.
- [Duress/receivership](DESIGN_IDEAS.md#absence-and-duress), [settlement decline](DESIGN_IDEAS.md#813-town-decline-ruin-and-deletion), [founding/territory](DESIGN_IDEAS.md#817-town-marker-territory-and-outposts) and [construction](DESIGN_IDEAS.md#101-building-and-blueprints) retain their own conditions. Proposed plans and algorithms are not approval of every building list.
