# Design proposals and pending status migrations

[DOC_MAP](docs/DOC_MAP.md) remains the index. This file holds proposals and recorded decisions pending status migration.

[Approved records](Design_Ideas_Approved.md) own or link each full specification once. [Built records](Design_Ideas_Built.md) distinguish implementation, tests and player evidence.

Recorded decisions migrate in bounded batches under Dave's 16 Nov instruction that documented decisions are his. Explicit proposals stay proposals; approved specifications are linked below. Migration does not certify implementation or tests. Section numbers and “above/below” refer to each linked source snapshot.

## Aging and lifespan

[Approved aging specification](Design_Ideas_Approved.md#aging-and-lifespan) owns the recorded decisions, exact values, qualifications and source receipt.

### Ideas and proposals — not approved

- **[Idea]** In their early 20s, players will hopefully settle down, establish a home and a spouse, and make that their base of operations.
- **[Idea]** The base can be in a town that belongs to another player or to the player. A town belonging to the server was also mentioned. The developer-built starter town (Section 8.1) is the first such town.
- **[Idea]** Couples realistically keep having children, about one every year or two, and twins are possible. That is one every 15 to 30 real days, or about a dozen children between parent ages 22 and 40 over about nine months of real time.
- **[Idea]** Population control: if a family has many children, one might fall sick and die or have a farming accident.
- **[Proposed]** Tie that risk to conditions the player can see and influence (poor food, a crowded house, no healer nearby, unsupervised dangerous work) plus a low baseline of childhood illness for every family, instead of a penalty for family size. Food, housing and land costs make a large family a real expense. Child death is emotionally heavy and can affect age ratings, so it may need gentle handling.
- **[Proposed]** Ownership held at the **dynasty** (family line) level, so nothing needs transferring when a character dies. This is consistent with the heir inheriting everything that remains.
- **[Proposed]** Skills should feel competent in tens of hours and mastered in a few hundred, so a character gets time at the peak before aging slows them. That much play time needs enough depth to stay interesting.
- **[Proposed]** An NPC who starts at 25 and dies at 62 lives about 18 real months. A child takes about 9 real months to reach 18. A town's population therefore turns over in about two real years, so births, marriage and migration matter. Birthdays come every 15.2 real days.

## Children and family growth

[Approved family specification](Design_Ideas_Approved.md#children-and-family-growth) owns decisions and qualifications. Below are proposals and open questions.

### Childhood and teaching

- **[Proposed]** Teaching speed depends on the parent's own skill in the trade and the time they spend with the child. This links to the partial-training idea in Section 6.2.
- **[Proposed]** The child's own traits can pull against the markers, so a strong push against a child's nature gives slower, grumbling progress.

#### Open questions

- **[Open]** How much time teaching costs the parent, and whether NPC tutors or apprenticeships can stand in for the parent.

### Non-successor siblings

- **[Idea]** A sibling outside the succession line decides for themselves, using their traits, skills, memory and preferences, whether to stay with the dynasty or break off and live their own life.
- **[Idea]** A sibling might marry another player and join that player's dynasty, or take a local job (temple, inn) and become a town character who keeps a tie to the family.
- **[Idea]** A sibling who leaves chooses between their own house and living at the homestead, where their income counts toward the dynasty's income.

#### Open questions

- **[Open]** All of this is deferred. It needs the NPC decision system (traits, preferences, language) and the household income model first.

### Adoption and inclusion

- **[Proposed]** Requirements to adopt: the dynasty has a home, enough income to raise a child, and a good enough reputation. A child who is adopted becomes family and can become the successor.

#### Open questions

- **[Open]** How an adopted child's traits and background are generated, how the temple decides between applicants, and the age limit for a child to count as adoptable.
- **[Open]** Whether other routes should exist (guardianship of a relative's child, fostering) and how they differ from adoption.

## Death and rescue

[Approved death/rescue specification](Design_Ideas_Approved.md#death-and-rescue) owns decisions and qualifications. Below are proposals and questions; source-relative “above/below” refers to its linked original snapshot.

### Danger, rescue and logging out

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

- **[Proposed]** The heir's retrieval quest (above) leads to these remains, so the mechanics line up: a creature that took the gear makes a hoard to raid.
- **[Proposed]** Remains are a flat image facing the player over a mark on the ground. NPC adventurers who die leave remains too, and each tile keeps at most 50 sets, with the oldest turning to bones only. Remains placed by the server at world start (old adventurers, Section 4.13) are scenery and do not follow this timeline.
- **[Proposed]** Details (tunable): the fee is about 10 percent of the value of the gear retrieved, with a minimum of 1 gold, and it is paid before the gear is handed over. The wizard can only fetch gear that is still on the remains: gear already taken by a creature into its hoard stays there. He fetches only your own gear and the gear of the NPCs in your party (see below), never another player's or anyone else's. A town with no wizard tower cannot offer the service, which gives the wizard tower another use (Section 8.15).

### Staying alive

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

See [qualifications and historical evidence](Design_Ideas_Approved.md#qualifications-and-working-evidence), including the unresolved remains-expiry boundary.

## Succession and inheritance

Source: [DESIGN_IDEAS §§6.2 and 6.7](https://github.com/DSul3791/DynastyALWL/blob/dbe793cbcbe04d2207a33e7fd8e2e1edbf266d13/DESIGN_IDEAS.md#62-what-an-heir-inherits). Extracted 16 Nov 2026.

### What an heir inherits

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** The heir inherits equipment, businesses, properties and bank accounts. The only thing missing is the character's personal skills.
- **[Decided]** Debts pass to heirs along with everything else. A debt that expects a regular payment becomes the heir's obligation, stays on the books and is paid accordingly.
- **[DIRECTOR-APPROVED — Dave, 16 Nov 2026]** See [the successor's first responsibility](Design_Ideas_Approved.md#successors-first-responsibility--estate-debts): arranging estate-debt payments. The gameplay dynamic is deferred; do not address or implement it now.
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

The offer order and final-child fallback are [director-approved](Design_Ideas_Approved.md#succession-order-and-final-child-fallback). Other legacy details below retain their recorded status.

#### Recorded decisions and approved clarification

- **[Decided]** Only the chosen successor inherits. The whole dynasty passes to that one person. It does not matter which spouse a child came from, since all are the head's children and all are eligible to be successor at retirement or death.
- **[Decided]** **Retirement is the player's choice, driven by aging.** As a character ages, their skills fall with their physical ability. At some point the player decides it is time to move on, makes sure a successor is chosen, and chooses to retire. This is usually a conversation with a spouse. There is no fixed retirement age.
- **[Decided]** **Retirement.** A character who lives into old age and becomes too old and frail to carry on can choose a successor and retire. The player then takes over the successor's body, and the retired character becomes a senior or elderly NPC who lives out their remaining days on the farm.
- **[Decided]** **Naming a successor can be tested while alive.** Because NPCs talk through the language model, a player can say to a child, stepchild or spouse, "I am thinking of making you my successor", and they answer as themselves: proud, nervous, or unwilling. Naming someone does not bind them. They can still decline when the handover comes.
- **[DIRECTOR-APPROVED — Dave, 16 Nov 2026]** The offer order is defined once in [approved succession order](Design_Ideas_Approved.md#succession-order-and-final-child-fallback). It replaces the former global blood-child age order; this subsection remains the legacy route.
- **[Decided]** **Each person in line chooses; with no will, the chain is the order of asking.** The chain is the order in which the offer is presented. Each person in turn may accept or refuse, and a refusal passes it to the next in line. With no will, nobody is named, so the offer simply goes down the chain.
- **[Decided]** **A will raises the odds, but is never a certainty.**
  - If a successor is named, the chance they accept is much higher.
  - It is not 100% just because it is a parent's will. It is certain only if the successor agreed beforehand.
  - If a child told the parent they truly do not want it and is named anyway, the chance of accepting rises by about 50%, so it becomes a coin flip. If they refuse, it passes to the next in line.
  - **Character attributes decide the odds.** Loyalty, a sense of duty and greed each push toward accepting, so most people will accept. There is always some chance they will not.
  - The exception is the [approved final-child fallback](Design_Ideas_Approved.md#final-child-fallback), which overrides refusal only after all ordinary offers fail.
- **[DIRECTOR-APPROVED — Dave, 16 Nov 2026]** The mandatory fallback is defined in [final-child fallback](Design_Ideas_Approved.md#final-child-fallback). It applies to the final eligible child in the approved family order after all ordinary offers, including spouse offers, have been refused.
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

- Dave resolved the offer order and mandatory fallback on 16 Nov 2026; use [the approved specification](Design_Ideas_Approved.md#succession-order-and-final-child-fallback). Adoption eligibility remains a [proposal in the family collection](#children-and-family-growth); this clarification does not settle adopted-child placement.
- Naming someone is recorded as nonbinding, while prior agreement is described as making acceptance certain. Preserve both qualifications pending source review.
- Keep the distinct benefactor-only tax, protected-item rules, forced-property-sale/loan choice, tax cap, reputation discounts and transferred reputation together. No single rate or “nothing is taken” summary replaces their nested exceptions.
- [Death and rescue](#death-and-rescue), [aging](Design_Ideas_Approved.md#aging-and-lifespan), [personal finance](DESIGN_IDEAS.md#63-personal-finances), [duress](DESIGN_IDEAS.md#absence-and-duress) and [NPC memory](DESIGN_IDEAS.md#88-npc-character-memory-and-conversation) remain dependencies. Individual reputation versus dynasty credit averages is a distinction, not permission to invent a dynasty-wide reputation score.

## NPC population and migration

Source: [DESIGN_IDEAS §§8.2–8.3](https://github.com/DSul3791/DynastyALWL/blob/61cba95e7f41c0aa2528820835844f637262103b/DESIGN_IDEAS.md#82-npc-population). Extracted 16 Nov 2026.

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

- [Aging](#aging-and-lifespan) retains the differing NPC starting-age range; neither version is silently replaced. [Children/family](Design_Ideas_Approved.md#dependencies-and-unresolved-qualifications) distinguishes player-household pregnancy choices from NPC-population behavior.
- [Memory and conversation](DESIGN_IDEAS.md#88-npc-character-memory-and-conversation) and [language hosting](DESIGN_IDEAS.md#89-language-service-hosting) retain their detailed designs. Model/host examples above are historical proposals, not current product or licensing recommendations.
- [Death and rescue](#death-and-rescue) retains rare rescue qualifications; [duress](DESIGN_IDEAS.md#absence-and-duress) and settlement decline describe different causes of displacement. Player major-illness exclusions remain in [§8.1](DESIGN_IDEAS.md#81-towns).
- [NPC technical plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/NPC_DESIGN.md) and [first-island roster](TOWN_NPC_SPEC.md) are dated records with proposals, not current population censuses or blanket implementation evidence.

## Property and town management

Source: [DESIGN_IDEAS §§8.4–8.6, 8.14–8.16](https://github.com/DSul3791/DynastyALWL/blob/7311ee19374bdb5f0d369e92aee25db11f365e42/DESIGN_IDEAS.md#84-town-planning-and-the-civil-engineer). Extracted 16 Nov 2026.

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

## Founding and building a settlement

Source: [DESIGN_IDEAS §§8.17–8.20](https://github.com/DSul3791/DynastyALWL/blob/8516664b13661113d5f7bf2bfac481d296d14266/DESIGN_IDEAS.md#817-town-marker-territory-and-outposts). Extracted 16 Nov 2026.

### Town marker, territory and outposts

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** The town block is a marker with no physical form: a floating arrow only the owner can see, which the owner can switch on and off. It adds an entry to the owner's ledger saying they own a claim. It marks the exact centre of the town.
- **[Decided]** Until an office building is placed (a keep or castle with an office, a house with an office, a town hall or a magistrate's office), the owner cannot reach the town settings. The building is where the town manager lives and works.
- **[Decided]** **Towns cannot overlap, so the land is reserved up front.** Claims come in stages (camp, settlement, hamlet, village, town, city, grand city). A list gives the physical size of each, and the largest, a grand city, is the maximum a claim can grow to. Placing a town marker reserves land from the marker out to the size of a grand city, so nobody can place a marker anywhere that its own maximum city would overlap another town's. The aim is that one person can build a town into a giant city with a castle, thriving businesses and a guild of a thousand real players.
- **[Decided]** **The ladder sizes stand for now.** For scale, medieval London inside its walls was about 1.3 km², so a 1,000 m city is already large. Doubling every radius would cut the towns on a 50 km² island from about 5 to 7 down to 1 or 2. The sizes can be adjusted later, ideally with one scale setting for the whole ladder.
- **[Decided]** **One camp at a time.** A dynasty can hold only one claim below the hamlet stage. While you have a camp or a settlement, you cannot place another camp. You must first build it up to a hamlet, the stage where it has homes and villagers. Only then may you go exploring and place a second camp.
  - The camp is the tent. The settlement is the introductory stage where you prepare the ground for a liveable place. At the hamlet stage it actually has homes and villagers.
- **[Decided]** **An expansion costs what it really costs, and the money does not vanish into the server's coffers.** The cost of a step is the materials and labor the expansion needs: more builders, more guards, more supplies, and wages for the people at the stonemason, the lumber mill and the rope making. It includes a new, bigger and stronger wall, for example palisade logs, then stonework, and spike walls outside the palisade.
- **[Decided]** **Costs are worked out from what the work takes.** Over time we calculate each expansion's cost from the materials it needs and the pay of the people who do it. Each stage must be priced with the next step in mind: once the expansion is done, the first building wanted next costs a certain amount, and the town needs the money to buy it, so that building can earn the money for the one after.
- **[Decided]** **Homestead.** A homestead is a home, not a town. It starts like a camp: the player places a marker and a tent, and that is a **homestead camp**. It does not grow into a town. It grows into a bigger home instead, such as a house, then an estate, then a keep or castle. The stages and sizes of homes are to be designed later.
- **[Decided]** An outpost reserves only its own area, whose size depends on its size class (Section 8.10).
- **[Decided]** A town has a **circle of influence** around its marker.
- **[Decided]** An **outpost** is claimed with an outpost marker, like a town marker. The owner can then put buildings on it and hire a manager. The kind of building decides the kind of manager and outpost: a mine manager, or a lumber mill with a master who runs a few NPCs who cut wood, bring it in, process it and ship it to the town.
- **[Decided]** Outposts and towns exchange goods by NPC travel, and that travel makes roads. The NPCs path-find by least resistance, so the first road between an outpost and its town is a rough dirt road formed by the travel itself. This is a system to build in.
- **[Decided]** When a route needs a bridge, the NPCs tell the town builder, who arranges builders and decides where the road and the bridge go.

#### Ideas and proposals — not approved

- **[Proposed]** The minimum distance between two markers is then twice the grand-city radius R. The settlement ladder below puts R at 1.5 km.
- **[Proposed]** **The settlement ladder.** A new claim is a **camp**: a marker and a tent. Each paid expansion grows it by roughly 50 percent in radius (a smaller step for the first two), and the size names follow. Radius includes the surrounding farmland, since the circle runs out to the farms.

| Stage | Radius | Area | Rough population (NPCs and players) |
|---|---|---|---|
| Camp (a new claim) | 150 m | 0.07 km² | the player and guards |
| Settlement (preparing the ground) | 200 m | 0.13 km² | up to 10: builders and guards in tents and barracks, no villager homes yet |
| Hamlet (first homes and villagers) | 300 m | 0.28 km² | 10 to 100 |
| Village | 450 m | 0.64 km² | 100 to 400 |
| Town | 675 m | 1.4 km² | 400 to 1,500 |
| City | 1,000 m | 3.1 km² | 1,500 to 5,000 |
| Grand city (the maximum) | 1,500 m | 7.1 km² | 5,000 to 15,000 |
- **[Proposed]** The reservation (above) is a grand city: radius 1,500 m, so two markers must be at least 3 km apart, and every marker reserves about 7 km² even while it is still a camp. A 50 km² starter landmass then holds roughly 5 to 7 towns, and a 100 km² landmass roughly 12.
- **[Proposed]** Details to work out later: if a camp or settlement is let go, lost or abandoned, the player may place a new one; buying an existing town is not limited by this rule; a hamlet that falls into ruin keeps its stage, so it still counts as a hamlet for this rule. This also limits marker hoarding (Section 15).
- **[Proposed]** Moving up a stage needs the paid expansion plus a floor of buildings and population, so a stage name means something. "Established" status (Section 8.18) does not depend on the stage: a camp with two guards is already established.
- **[Proposed]** **How to price a stage (tunable).**
  - Each stage has a plan: the new wall ring, new roads, the required buildings and the extra guards. The planner turns it into a bill of materials and a labor estimate. The gold price is that bill times the market prices, so it is calculated and not typed in.
  - Wall type grows with the stage: no wall for a camp (a tent), palisade for a settlement and hamlet, palisade with a ditch and outer spikes for a village, stone for a town and a city, stone with towers for a grand city.
  - The old wall is taken down and salvaged by its condition. A wall in good shape keeps all of its wood and all of its stone when it is taken down, so the next wall costs only the new material. Loss happens only through wear, down to each material's minimum integrity (Section 8.13).
  - A longer wall needs more guards: at least one guard for each 100 m of wall plus the one per 25 residents already proposed, whichever is larger.
  - **Balance test:** a stage is priced correctly when the town's net income at that stage repays the expansion in 1 to 2 game years (15 to 30 real days). If it takes longer, the stage is too expensive. If it pays back in days, it is too cheap.
- **[Proposed]** **Requirements still apply** (tunable): enough residents and buildings, so a stage name means something.

| Step | Residents | Buildings |
|---|---|---|
| Camp to settlement | none | a town manager building and a guard building, wages paid |
| Settlement to hamlet | 10 | the first ten, built, including homes |
| Hamlet to village | 100 | 25, including blacksmith, granary and mill, and healer |
| Village to town | 400 | 60, including a market hall and a second well |
| Town to city | 1,500 | 150, including a harbour or a major road hub |
| City to grand city | 5,000 | 400 |
- **[Proposed]** Population figures are guides, not caps. The NPC population cap per island and region (Section 8.2) and the language model budget (Section 3) limit the NPC share. The player share of a grand city is the thousand-strong guild case.
- **[Proposed]** Details (tunable): a dynasty has one homestead at a time, and it does not use up the one-camp slot of the town ladder. A homestead has a small fixed circle (suggestion: about 100 m, growing with the home), needs no town manager, and can be protected by two guards in the same way as a camp. It gets a small outpost budget (suggestion: 2 points, Section 8.10).
- **[Idea]** The planner prefers rings, working outward from the centre:
  1. The core: the keep or castle, the main storage and warehouse, the guards, and extra storage and housing that can take people in during a defence.
  2. Businesses and tradespeople: the blacksmith, merchants, sales stalls and inns.
  3. The waterfront, on the side with water: the harbour and port with bars, shanties, shipping businesses and agents. On the landward sides this ring holds small farms or more storage.
  4. Beyond that, farmland.
- **[Idea]** Bridges use bridge blueprints, or a special dynamic bridge blueprint that fits the gap.
- **[Idea]** Cheaper crossings: shallow fords that horses can walk through, or a causeway across shallows with pipes or culverts for the water.

#### Open questions

- **[Open]** Whether the rings are fixed rules or only planner preferences, the maximum span and water depth of a bridge, the kinds of bridge (rope, timber, stone), and who maintains roads formed by travel. (Expansion costs come from real materials and labor, and abandoned markers are claimed as in Section 8.13.)

### Road, mine and tunnel builders

#### Ideas and proposals — not approved

- **[Idea]** **Road builder (player tool).** The player picks two points on the map. The builder works out what it thinks is the best route, weighing slope, shortest or shallowest water crossings (a ford where shallow, a bridge where not) and where bridges are placed. It shows the proposed path, and only after the player approves does it do the ground work (levelling, averaging, smoothing) and build the road surface in the chosen type. Road types, exact costs and workers are open. Related: the town planner (Section 8.4), road condition and wear (Section 8.13), blueprint levelling checks (Section 10.1).
- **[Idea]** **Mine builder (admin tool, not a player feature).** An administrator stands at a spot and says "dig a mine here". It places a small mine shack and an entrance, then digs the mine out in front of them: a descent at a chosen angle, cave bracing placed every so many meters (following the support and wear rules in Section 8.13), and a little randomness up and down and left and right so it looks hand-carved with a pickaxe and not laser-straight. It can also add side shafts at random and other small touches, and grow into a full working mine. At first it changes voxels in the living layer only (nothing is baked into the tile). An administrator X-ray view, or an AI that reads the tile's geology and ore bodies, could pick a spot worth mining.
- **[Idea]** **Tunnel builder.** The same machinery, horizontal: it picks an entrance and an exit on opposite sides of a mountain and digs a reasonably straight tunnel between them (the Mines of Moria idea). If it breaks into a natural cave it adapts: a narrow gap gets a bridge or land bridge; a cave too big to bridge gets a road carved down one wall, across the floor and up the other side. Once built, a tunnel is a normal route option for the road builder, like a ford or a bridge.
- **[Idea]** **Tunnel types.** Small, creepy tunnels, up to epic dwarven ones. The grand dwarven road is a highway through the mountain: wide enough for oxen and carts to pass travelers coming the other way, very high ceilings (so the smoke of giant braziers, the light source, can rise and stain the ceiling dark), massive bridges on tall pillars down to the cave floor over any cave however large, and enormous, magically opened doors at the entrances. Dwarves like things grand.

#### Open questions

- **[Open]** How the road builder relates to the NPC-formed dirt roads (above): whether it follows and upgrades them, whether it reuses their route, and who maintains the result.
- **[Open]** Mine builder questions: how it relates to the player mine outposts and the mine chain (Section 11.2, supports and bracing) if at all, whether players can own or claim an admin-dug mine afterward, whether it can author dormant mineshafts and lairs (Section 4.4), and how tunable the randomness and the bracing interval are.
- **[Open]** Tunnel types and costs, who may build tunnels (admins only, or players as large engineering projects), the maximum tunnel length, and the door magic.

### Becoming established, water, and the first steps for a new character

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **A camp is established by two guards.** A claim starts as a camp: a marker and a tent. If the player has two NPCs travelling with them, they can assign them as guards, and the camp is immediately established and PvE safe (and protected from hostile takeover, Section 8.14). Their wages are paid as for any guard.
- **[Decided]** **From a settlement up, established is two buildings and a payroll:** a town manager building and a guard building, with the guards' first wages paid. A well and a temple are not required.
- **[Decided]** **Wells.** A well provides clean water without limit up to a number of units per day. A small population has plenty from one well. A larger one needs several. A town with no well can buy water and food from another city on the same island or on a neighbouring island.
- **[Decided]** **The design goal for the beginning:** the start is challenging, with a little ramp-up and onboarding. Once the hard early work is done, things get easier, so the early investment is valuable and players do not want to start over.
- **[Decided]** **A starting character's first steps.** Work on the starter island: freelance harvesting, adventuring, fishing and hunting, and selling goods at the starter village market, until there is enough wealth either to build their own town on the starter island or to build or buy a first ship.
- **[Decided]** **Getting a first ship.** Two ways:
  - Pay for the blueprint and gather all the materials yourself.
  - Pay a shipyard to build it. You provide all the game currency, the shipyard builds it over time, and you can watch it being built while you keep adventuring on the starter island.
- **[Decided]** **A ship is the first base.** It has value, can carry shipments and deliveries, and can go adventuring. A player can log out in it while anchored in friendly waters.
- **[Decided]** **Ship wear.** A ship degrades very little, or very slowly, over time. Damage comes from running into other ships, hitting rocks, very bad weather, or being shot by enemies.
- **[Decided]** **Many tiers of boats.**
  - Very small boats for getting around an island and fishing.
  - Small boats that handle longer voyages and are faster because they are longer.
  - Long, narrow boats built for speed.
  - Bigger, heavier boats built for cargo.
  - Massive ships at the top, which take days to build and are never starter boats.
- **[Decided]** **Build time grows with size.** The smaller the boat, the faster it is built. A first-tier boat is ready in about 6 game hours (15 real minutes; it may even be bought already built), the next tier about 12 game hours, then 18, then a full game day (one real hour). At the large end, the basic frame, deck and sails of a big ship takes about 24 game days (a full real day). Nobody should wait an hour or two of real time for their first boat.
- **[Decided]** **What a shipyard sells.** A purchase from a shipyard is the basic boat: hull, sails, anchor and decks. The owner installs the steering wheel and fits the ship out, as in Atlas, if it is a bigger ship. Smaller ships are pre-designed, again like Atlas.
- **[Decided]** **Boats are trade goods.** A town with its own shipyard can build boats for other players and sell them. An owner can sell a boat to someone else.

#### Ideas and proposals — not approved

- **[Proposed]** Suggested numbers (tunable): one well supplies 50 residents. Requests to buy supplies reach towns within 2 tiles (about 31 km) of the town marker, which keeps the supply route within one day's sail. Supplies arrive by NPC cart or ship, so delivery is not instant.
- **[Idea]** The boat system is imagined as similar to Atlas. When we start building it we will review what we like and do not like and decide then.

#### Open questions

- **[Open]** Whether the supply distance is server-wide, a number of tiles or a number of kilometres (the suggestion above is a number of tiles).
- **[Open]** Build times for the middle and top tiers, prices, blueprint prices against finished ships, and where players can anchor safely when logged out.

### The first ten buildings

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **The town manager building comes first.** It is the building where the owner makes decisions. The owner can hire a town manager to run it. Once there is a town manager, the same building can also hold a **town planner**, who uses AI to scan the area and decide where natural roads would go and where to put the well, the temple and the guards.
- **[Decided]** **The temple costs the town money but lifts the base town spirit.** It is a liability, but it gives a place for orphans, counselling, food or financial help, and protection. The **well** has upkeep, which is a cost to the town.
- **[Decided]** **Walls and the inner circle.** From the settlement stage up, a claim is surrounded by a wall (a camp is only a tent), even if it sits next to the water, so there is no open area that lets people into the innermost circle. The inner circle holds the core buildings, such as the manager's house and the guard house. The **harbour is always outside the wall**. The sawmill and the stonemason are **temporary fixtures** that start near a gate and are gradually moved further out of town later.
- **[Decided]** **Self-sufficient from the start.** The first settlement needs wood, stone and rope. Rope comes from harvesting plants for thatch and fibre. At first, rope and wooden pins join beams together to build walls, buildings and joinery. These are the rustic starter buildings, upgraded and improved over time. A blacksmith comes later. Until then the settlers can bring nails and hinges, or raw iron, bought at the starter village.
- **[Decided]** **The settlement starter kit.** A kit sold as one heavy box that takes one inventory slot. It would fill the weight of a second- or third-tier starter boat. It contains everything needed to start a town or a homestead camp, and the player must earn the money to buy it first.

#### Ideas and proposals — not approved

- **[Proposed]** **The ten things a new settlement needs, in the order the planner builds them:**
  1. **Town manager building** (also the owner's house if the owner wants to live in it). Everything starts here.
  2. **Roads and the central square**, laid out first by the planner, with the well in the square.
  3. **Sawmill** (a lumber yard), near the gate on the road to the forest. Temporary.
  4. **Stonemason** (with a quarry crew), near the gate on the road to the mountains or quarry. Temporary.
  5. **Guard barracks**, with a guard captain and guards. Then the wall and gates.
  6. **Weaver and rope maker.** Uses fibre and thatch for rope, baskets, nets and cloth. Rope is how the first buildings are joined.
  7. **Storehouse** (settlement warehouse).
  8. **Homes** for the builders, at least three cottages.
  9. **Inn** with rooms and market stalls. Tents come first (see Section 8.20).
  10. **Temple** (a small chapel). A cost, but it lifts the base town spirit.
  The wall and its gates are infrastructure, not one of the ten. The blacksmith, granary and mill, farmland and healer come in the second wave.
- **[Proposed]** **What comes next** (second wave): blacksmith, granary and mill, farmland, tannery, baker and butcher, healer, a second well, more homes, the harbour and shipyard outside the wall, and then the sawmill and stonemason moved further out.
- **[Proposed]** **Space needed (estimates).** Inside the wall, with yards: manager building 200 m², well and square 1,600, barracks 400, storehouse 300, weaver 300, homes 840, inn 400, temple 400. Together about 4,400 m². Roads and paths add about 30 percent and room to grow doubles that, so the walled core is about 1.2 hectares. A wall around it at a radius of about 70 to 75 m is about 450 m long, with two gates, one toward the resources and one toward the water. The sawmill and stone yard sit just outside the gate, and the 200 m circle of a settlement (12.6 hectares) leaves the rest for farmland.

#### Open questions

- **[Open]** Whether the first ten are the right ten, the exact footprints, and what the expansion steps cost (Section 15). Expansion is decided after the building list and sizes are settled.

### Building a settlement: the planner's order

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **The manager building.** The owner can live in it and can run the town without hiring a town manager, and can build everything by hand. The game makes this easier with NPCs who take up the jobs.
- **[Decided]** **A planner hired into a town** (with an owner and a town manager) is responsible for hiring a couple of builders. The planner studies the terrain around the manager building and plans in this order:
  1. Where the starter roads go, with room for a town square or circle, thinking about long-term growth.
  2. The blueprint for the wall around the property, at low priority so it is not built first.
  3. The sawmill and the stonemason near the opening in the wall where the road to the forest or the mountains passes, so resources come straight in. These start their logging and quarrying crews, and can hire NPCs to gather stone or dig it from the nearest mountain or quarry site.
  4. Then the first barracks, the guard captain and guards, then the wall and the gates.
  5. Whatever buildings supply the next materials needed.
  6. The first houses, because the builders need somewhere to live.
- **[Decided]** **Gates close at night.** Every worker comes in at dusk and must be inside before the gates close. At dawn the gates reopen and the working day continues.
- **[Decided]** **Tents first.** Early on, supplies include tents that are set up during construction. Inside is a campfire in the middle, and each side of the tent has a bed and a storage chest. They are temporary shelter from the weather until the inn and houses are built.
- **[Decided]** **Hiring guards once the barracks stands.** The owner or manager can hire any available guards in the area, meaning existing NPCs with guard experience. Their wages are set by their experience, and also by how hungry they are and how low their own spirit is from being poor or unemployed.
- **[Decided]** **If no guards are available,** the barracks suggests four randomly generated new guards. They live in the barracks. Each has their own attributes, characteristics and skills.
- **[Decided]** **The guard captain.** Given enough time, one guard is promoted to guard captain by the town manager, or by the owner if the owner plays that role. The captain manages the guards and assigns patrols and night watches. Other jobs for guards will be added later.
- **[Decided]** **Wage negotiation with a step-up.** A veteran guard who is tired and hungry may agree to start at a lower wage, but expects a raise over the year toward veteran pay: a small increase each month, agreed in the negotiation.
- **[Decided]** Guards who are generated for the barracks live in it. Other guards hired from the area may live in their own homes and report to the barracks. The player character chooses a place to live eventually.

#### Ideas and proposals — not approved

- **[Proposed]** **Trades.** Fibre and thatch go to a weaver and rope maker, who makes rope, baskets, nets and cloth. Guards report to the barracks. Whether they live in it or in their own houses is open.
- **[Proposed]** Wage rule to start with: a base wage times a factor for experience (0.8 for a rookie up to 1.5 for a veteran), times a discount of up to 30 percent for a guard who is hungry or has been out of work for a long time. The base wage is set with the rest of the economy. Guards who need work take less, but are less loyal if they feel underpaid later.
- **[Proposed]** How the step-up works: the raise per game month is the gap between the starting wage and the veteran wage, divided by 12, so the guard reaches full pay at the end of the first game year (15.2 real days; a game month is about 30 real hours). If the town skips a raise, the guard's loyalty falls and they may quit. The language model speaks the negotiation, but the game keeps the figures.

#### Open questions

- **[Open]** The base wage and the pay scale, and what else guards do besides patrols and night watches.

### Dependencies and source-review qualifications

- [Town/starter-town rules](DESIGN_IDEAS.md#81-towns) retain the separate founding ideas and designated-server-town exceptions. The proposed first-ten building list does not override the recorded planner order; original approval sources for that order remain unverified.
- [Property and management](#property-and-town-management) retains permissions, plan approval, guard protection and notice windows. [Outposts](DESIGN_IDEAS.md#810-outposts-and-town-satellites) retains points, business and slope proposals; the stage/territory tables here retain every numeric qualification.
- [Construction](DESIGN_IDEAS.md#101-building-and-blueprints) is a historical dependency. Current item/recipe definitions and construction behavior route through [DOC_MAP](docs/DOC_MAP.md); old starter kits, rope/nails and tier examples here do not authorize catalog changes.
- [Decline](DESIGN_IDEAS.md#813-town-decline-ruin-and-deletion) retains the distinction between keeping a town's stage and losing its wealth/buildings. No stage table is evidence that founding, guards or NPC builders are implemented.

## Outposts and settlement decline

Source: [DESIGN_IDEAS §§8.10 and 8.13](https://github.com/DSul3791/DynastyALWL/blob/c5dcfdc3cf91580aa6bbf8a5870b8ae8ce62769e/DESIGN_IDEAS.md#810-outposts-and-town-satellites). Extracted 16 Nov 2026.

### Outposts and town satellites

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** An outpost is claimed with an outpost marker, in the same way as a town marker (Section 8.17).
- **[Decided]** **The basic outposts for now:** a logging camp, a stone quarry and a mine. A quarry is an open pit worked from the surface; a mine is drilled, with a shaft that goes down into the ground. The full list of outpost types and their rules will be decided later.
- **[Decided]** **Setting up an outpost.**
  - The player places an outpost marker and adjusts the area, the same way as placing a blueprint (including the ground check, Section 10.1).
  - The only prefabricated piece is a small building such as a mining shed. It designates the area. A line marks the border of the outpost, visible in building mode.
  - Once set up, the owner can hire NPCs to work it, from the existing pool of unemployed NPCs or from newly manufactured ones. They start working the area immediately.
  - The outpost comes in four sizes: small, medium, large and colossal.
- **[Decided]** **The size of a settlement limits its outposts.** The bigger the claim, the more outposts it can support, and the bigger they can be. A settlement might support two small outposts (say a logging camp and a quarry); a hamlet four small ones or two medium ones, so the owner can grow a quarry or add a mine. This is a working theory, to be rounded out as it is built.

#### Ideas and proposals — not approved

- **[Idea]** A town on a good island has lots of land. Satellite outposts can be built on the hillsides of the mountainous island chains: a mine, a dock and an outpost master. Mines ship supplies back to the town. An outpost needs less room and can handle steeper slopes right next to the water.
- **[Proposed]** Measured on the first world sketch (`plan/buildable_summary.txt`): 36 islands have room for a town, but 289 have an outpost site (a foothold of at least 0.05 km² on slopes up to about 17 degrees at the shore, with water at least 8 m deep within about 500 m for a dock). 253 of those have no town site, so outposts are how most islands get used, and the volcanic chains in hard and deadly waters (134 outpost islands) become mining frontiers.
- **[Proposed]** An outpost is a business in the shared business structure (Section 13.4), owned by a town or player and run by an outpost master NPC. It claims a small plot (an outpost block with a much smaller radius than a town block) and links to its parent town's warehouse by a sea route. Ships run that route on a schedule (materialized only when seen, Section 3), carrying ore out and food, tools and wages in.
- **[Proposed]** Outpost blueprints are built for slopes: terraces, stilts, stairs and a jetty, so the blueprint leveling check (Section 10.1) allows steeper ground for them than for town buildings.
- **[Proposed]** Danger matters: outposts in hard and deadly waters need a palisade and guards paid by the parent town, and are natural targets for raids, pirates and sea creatures, which ties into threats and pacing (Section 12). Losing an outpost cuts a supply line rather than ending a town.
- **[Proposed]** Volcanic islands drop steeply into deep water, which makes them good for docks. The geology already favors them for ore: copper and gold on arcs, sulfur and gems on hotspot volcanoes (Section 4.9). When ore bodies are placed at bake time, some should sit near outpost-friendly coves so mines and docks pair naturally.
- **[Proposed]** The generator does not need to bake outpost sites: they can be found at runtime from the tile maps (slope, height, shoreline, water depth), the same way the town planner surveys land. Natural harbors and coves can still be marked as sites at bake time.
- **[Proposed]** **Outpost points (tunable).** Each outpost has one of four sizes: **small, medium, large and colossal**. Its size costs points from its parent claim's budget: small 1 point (radius about 50 m), medium 2 (about 100 m), large 4 (about 150 m), colossal 8 (about 250 m). Growing an outpost costs the difference in points, plus the real cost of the expansion. The budget grows with the stage:

  | Parent stage | Outpost points | Example |
  |---|---|---|
  | Camp | 0 | none yet |
  | Settlement | 2 | two small outposts (logging camp, quarry) |
  | Hamlet | 4 | four small, or two medium |
  | Village | 8 | a large mine plus several small outposts |
  | Town | 12 | |
  | City | 20 | |
  | Grand city | 32 | |
- **[Proposed]** A watchtower or pigeon coop is always small. Other minimum sizes will be decided with each outpost type.
- **[Proposed]** Outposts may sit outside the parent's circle of influence, even on another island, and still count against the parent's budget. Each outpost needs guards and upkeep paid by its parent, so the budget is a money limit as well as a points limit. A town never drops a stage: it keeps its stage (a city stays a city) and falls into ruin instead (Section 8.13). Its outposts stop being paid and decline with it, as the mine rule describes (Section 11.2).
- **[Proposed]** Homesteads and individual players who own outposts directly get a small fixed budget (suggestion: 2 points), not tied to the town ladder (Section 8.17).

#### Open questions

- **[Open]** The exact point values and budgets, the list of outpost types and their minimum sizes.

### Town decline, ruin and deletion



**Decline of a player-owned town**

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** **Two roads to an abandoned town.** (1) The owner says "let it go" or never answers the notice: the town falls to rubble and anyone can claim the marker for free ("Claiming an abandoned town" below). (2) The owner's dynasty falls into receivership and nobody takes it over: the town reverts to the server, declines under server ownership, and is sold from the server list (Section 8.16) before it falls apart. Designated server towns (Section 8.1) never decline.
- **[Decided]** A town always has an owner. Its welfare is paid from the town's coffers. When the coffers run empty, the owner can top them up from their own wealth or let the town lapse. They still own it either way.
- **[Decided]** **A lapsing town breaks down step by step.** There is not enough money to pay for things, so the town starts cutting costs and getting rid of its weakest links by firing people. The core survives longest: guards, healing, the inn, the temple and the well. Maintenance of the walls, gates, roads and the like is cut back constantly.
- **[Decided]** **People leave one by one, by their own reasons, not at a fixed time.** A guard does not simply quit after a month without pay. Whether and when someone leaves depends on whether they are eating, whether they are living well, and what is happening to the town's spirit. It also depends on their attributes and traits: they may be very loyal but bad at handling stress, or stalwart people who weather any storm. Some leave early and some late, and the town gradually collapses.
- **[Decided]** **The last to leave is the town manager,** who quits when the last coin is gone. The owner gets a notification and has **24 real hours** to act before the manager quits. The owner can put more money into the sinking town or say "let it go".
- **[Decided]** **"Let it go."** The town is flagged for further degradation. It falls into disrepair and collapses in on itself into piles of rubble. The moment the owner says let it go, anyone can come along and claim it (see "Claiming an abandoned town" below).

#### Ideas and proposals — not approved

- **[Proposed]** How the leaving rule could work (tunable): each NPC has a stay score worked out from pay received, food, housing, town spirit and their own traits (loyalty, stress tolerance, stubbornness). They leave when it falls below a personal threshold, with some randomness. When the town cuts costs, it fires the lowest-value jobs first and keeps the core roles. A role's rank is set by how much the town needs it, not by pay.
- **[Proposed]** If the owner never answers the 24-real-hour notice, the manager quits and the town is treated as let go. The notice goes out through every channel the owner has, with the in-world delay (Section 8.15).

**Decline of a town that reverted to the server** (not a designated starter town, which never declines; see Section 8.1)

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** A town that stays server-owned loses spirit gradually and loses money, because it keeps paying for food and upkeep. When the money runs out the town falls into decay.
- **[Decided]** Once decay reaches a certain stage, every building slowly falls down. NPCs die off, move to other towns, join bandit camps, become bandits, or find work elsewhere.
- **[Decided]** Value drops as buildings decay and people leave. At the last moment of a town's life there is nothing but ruins and a town manager who has not yet left. A player can then buy the town for pennies on the dollar.
- **[Decided]** A new owner pays to hire the town manager and new builders, chooses the order of the rebuild and approves each rebuild. The blueprints and the dilapidated buildings are still in place.

**Flagging for deletion**

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Flagging for deletion happens when nobody bought the town from its manager. At that moment the town manager leaves his post and the town's ledgers and ownership are gone.
- **[Decided]** An administrator can flag an abandoned town for deletion, and the server administrators vote. A flagged town is not removed. Its buildings keep degrading at the regular speed, looking more worn and dilapidated until each collapses into rubble. Players can walk through a collapsing town and see that one used to be here.
- **[Decided]** The manager becomes an ordinary NPC, available for others to hire. He keeps his skills and whatever money he held, and he lives on it until he finds work or falls into poverty over time.
- **[Decided]** The town marker stays, and so does the town's office building (dilapidated, like the rest). The marker is the centre of the town, and the town's circle of influence spreads from it. What is left is the marker, the office, roads and rubble.
- **[Decided]** The office keeps the town's blueprints and its history: which buildings it had, its peak income, its farming and trade, its name and its previous owners.

**Degradation and rubble**

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Nothing disappears outright. Degradation takes some material away from each building (see below) and the rest falls into rubble that stays until someone harvests it.
- **[Decided]** The pile is called **rubble**. It is an item with models, and it is a chunk of the world.
- **[Decided]** Every building has a bill of materials from its blueprint. As it ages without care it slowly loses material (hinges break, nails rust and weaken, untreated wood suffers sun rot). When it collapses, the rubble holds its bill of materials minus what degradation took.
- **[Decided]** **The wear rule: slow while cared for, accelerating when not.** Everything that wears (buildings, supports, roads, equipment) follows one rule.
  - While it is owned and maintained, it wears slowly from a good state, and repairs restore it.
  - From the moment care stops, wear speeds up the longer care is missing: a tiny amount in the first stretch, noticeably more in the second, more again in the third, and so on, so the worse it gets, the faster it gets worse.
  - Each kind of thing has a **time to failure** `T`, the game time from stopping care to reaching its lowest condition. The condition lost is `(t / T)` squared, where `t` is the time since care stopped, scaled down to the material's floor (next bullet). Squaring gives the speed-up: wear in each step is bigger than in the one before. (Starting shape; tunable.)
  - `T` is adjustable for everything: every material, building, support and piece of equipment has its own value in data, not in code.
- **[Decided]** **Minimum integrity.** Every material also has a **minimum integrity**, the lowest condition it can wear down to, as a percentage of its original strength. Stone is always 100 (it never wears). Wood might wear only to 50. Treated wood might wear only to 75. The floor depends on where the material is: structural wood standing outside, in rain, sun and wind, might floor at 50, while the same wood in a mine, out of the weather and the sun, might floor at 75. Condition never goes below the floor, no matter how long care is missing.
- **[Decided]** Degradation is partial, and each material stops at its minimum integrity (see the wear rule above). Rubble holds the bill of materials times each material's condition. Using the starting floors for outdoor buildings: a blueprint of 1000 stone, 2000 wood, 100 iron and 200 slate leaves at worst 1000 stone, 1000 wood (floor 50), 70 iron (floor 70) and all of the slate.
- **[Decided]** Rubble is a salvage source. A player who reclaims a town can harvest the rubble for most of the rebuild materials without cutting thousands of trees.
- **[Decided]** **The terrain stays as it was.** The ground under a fallen town does not reset. Whatever the terrain looked like while the town stood (levelled ground, foundations, cuts and roads) is what it still looks like after the buildings fall, because nothing in the world would explain it changing. The world is made from the seed and the baked maps, and every change players and towns made is kept as a record in the server's living layer on top of that, and is applied again each time the area loads.

#### Ideas and proposals — not approved

- **[Proposed]** Starting examples (tunable, held in data): stone 100; metal 70 outdoors and 85 indoors or in a mine; untreated wood 50 outdoors and 75 in a mine; treated wood 75 outdoors and 90 in a mine. The floor and `T` are chosen per material and per setting (outdoors, indoors, underground).
- **[Proposed]** Starting numbers: a mine's supports have `T` = 168 game days, which is one real week, so a player who is away for a week finds the supports at their lowest condition (their floor). Using steps of one real day (24 game days), the condition lost is:

  | Real days since care stopped | Game days | Total condition lost | Lost in that day |
  |---|---|---|---|
  | 1 | 24 | 2% | 2% |
  | 2 | 48 | 8% | 6% |
  | 3 | 72 | 18% | 10% |
  | 4 | 96 | 33% | 15% |
  | 5 | 120 | 51% | 18% |
  | 6 | 144 | 73% | 22% |
  | 7 | 168 | 100% | 27% |

  **Duress stacks with the wear rule.** Neglect and duress are separate causes. A building is neglected when the dynasty has no money to pay for care. A dynasty is under duress when its player does not come back to the game. A dynasty can have either or both. When both apply, duress makes wear up to 1.5 times faster on top of the neglect speed-up (Section 6.1).

  Maintained wear is much slower: about 5 percent of condition per game year, restored by repairs. Buildings and roads get a much longer `T` than a mine (tuned later), so towns last longer than mines. Because the server only needs the time care stopped, the condition is worked out lazily when someone looks.
- **[Idea]** Salvage as a trade: businesses that go around clearing rubble from ruined towns and selling or reusing the materials. Harvested rubble is gone, and the harvester gets the contents minus degradation.
- **[Idea]** Wood left in rubble could count as aged wood (and in some places petrified wood), a different material from fresh wood with its own uses and quality. Treated, maintained wood degrades much more slowly.
- **[Idea]** Iron in rubble could slowly rust over a long time, giving less usable metal, while stone never changes. This is only a flavor idea and is left open.
- **[Proposed]** Rubble is stored as a pile of counted materials, not as individual pieces, so large ruined towns stay cheap to store and to draw on the minimum machine. Harvesting reduces the counts.
- **[Proposed]** Rubble is stored in the living layer as a record per pile: position, size, counts of each material and age. One pile per 100 m² of building footprint, so a large ruin can be harvested a bit at a time.

**Roads**

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Roads barely degrade (perhaps by a percentage) and never fully disappear. Buildings fall down and become rubble. Nothing erases itself completely.
- **[Decided]** Roads have visible condition. In a maintained town a road looks pristine, with no grass growing through it. A road in disrepair looks different (grass, mud, ruts).
- **[Decided]** Road condition has effects. A road in good repair lets you travel faster. A road in disrepair is muddier: it slows travel and makes travelers dirtier.

#### Ideas and proposals — not approved

- **[Proposed]** Road maintenance is paid by the town, so road condition follows the town's money and spirit. A road between towns could be maintained by whichever town owns the stretch, or by tolls (Section 13).

**Claiming an abandoned town**

#### Recorded decisions — SOURCE UNVERIFIED

- **[Decided]** Anyone can open an abandoned town's office without claiming it and read that history before deciding.
- **[Decided]** Anyone can claim an abandoned town by taking over its marker, and claiming costs nothing. Nothing stops a claim.
- **[Decided]** A claimant uses blueprint mode to see every building of the old town as an outline, with what it was and the materials it needs. The rubble beneath each outline holds most of those materials. The owner harvests rubble piles and puts the materials into a blueprint, which rebuilds that building.
- **[Decided]** The owner can hire a town manager, builders and guards when affordable, or cut trees and build alone or with friends, or turn the place into a small farming community until they can afford a manager. All of these paths are open.
- **[Decided]** No limit or cooldown on claiming abandoned blocks. Travel by foot, horse and ship is slow, so the distance itself is the limit.

#### Ideas and proposals — not approved

- **[Proposed]** The rebuild order is the owner's choice. A natural order is the town hall, then the temple and the well (which also raise the spirit floor, Section 8.12), then guards and the rest.

**Open**

#### Open questions

- **[Open]** How many road condition levels exist, how dirt and cleanliness work for characters, and who owns and repairs roads between towns.
- **[Open]** How an abandoned block's circle of influence interacts with a new town block placed nearby, and whether a claimed town starts with the old spirit or a fresh low one.
- **[Open]** How long each stage lasts, what the decay stages are called, the thresholds that trigger collapse, how many administrators must vote, and what happens to a town's records when it is deleted.

### Dependencies and unresolved qualifications

- Designated starter towns are distinct from towns reverted to server ownership: [§8.1](DESIGN_IDEAS.md#81-towns) keeps the protected-town rules; [property/management](#property-and-town-management) keeps purchase, notice and takeover conditions. No generic decline summary replaces those exceptions.
- [Founding](#founding-and-building-a-settlement) keeps stage/territory tables. The point/radius budgets here remain proposals and “working theory” retains that qualification despite its legacy decision tag.
- Dynasty [duress/receivership](DESIGN_IDEAS.md#absence-and-duress) and town decline use distinct clocks and causes. The game's proposed ruin/deletion rules are gameplay design, not authorization to delete documentation or player work during this mission.
- Preserve abandoned-claim protection, ownership, repairs, rubble/road persistence and deletion conditions together. Current behavior, approval sources and all tuning remain unverified here.

## Historical provenance leads — 16 Nov 2026

Aging/clock/lifespan: [bb524cc, 14 Oct](https://github.com/DSul3791/DynastyALWL/commit/bb524cca918855d002efa71b3189749eed833c4e). Succession/loan wording: [8e6fe51, 14 Oct](https://github.com/DSul3791/DynastyALWL/commit/8e6fe51dce5709593fcaacafe92b61ca90715777). Both cite [Claude session 01FW2oP4t11pHqGQwUfqgGZ9](https://claude.ai/code/session_01FW2oP4t11pHqGQwUfqgGZ9); inspected commits did not expose original answers. These are recovery leads, not an approval prerequisite after Dave's clarification. Aging decisions now reside in [Approved](Design_Ideas_Approved.md#aging-and-lifespan); other topics migrate in bounded batches.

## Personal finances and obligations

Source: [DESIGN_IDEAS.md sections 6.3–6.4](DESIGN_IDEAS.md#63-personal-finances), migrated 18 Nov 2026 without changing the design. Historical `[Decided]` labels below are recorded decisions, not newly verified direct approvals; source approval is not independently verified. No implementation, testing or player verification is asserted. References to Section 13.5 and the while-away report refer to the original source document.

### Personal finances

- **[Decided]** Each individual has a finances tab showing what they own, what they owe, how much they have banked and how much they carry on them.
- **[Decided]** Money in the bank is reached at the bank in person. A character away from their own town can instead try to write a letter of credit, based on their reputation (Section 13.5).
- **[Proposed]** The tab also shows a calendar of upcoming payments and a forecast ("your account covers the next three payments").
- **[Proposed]** Carried cash is exposed: it can drop on death or be stolen like any item. Banked money is safe but needs a visit to a bank.

### Obligations

- **[Proposed]** Loans, tax bills, wages and tolls are all one kind of record: who owes whom, how much, and when it is next due.
- **[Proposed]** At each periodic settlement the server pays what is due from the account, whether or not the player is online. A payment that cannot be made is a missed payment, with a reputation hit and eventually penalties or seizure of collateral.
- **[Proposed]** Missed payments while away appear in the "while you were away" report.

