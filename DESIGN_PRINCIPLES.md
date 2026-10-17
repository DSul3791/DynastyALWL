# Design Principles

The underlying philosophy behind the game: the values and reasoning that guide which rules we pick. Think of it as a constitution for the designers (the project owner and Claude). It holds the *why*, not the rules themselves. Game rules and mechanics live in `DESIGN_IDEAS.md`; ideas the project owner has turned down live in `DESIGN_REJECTED.md`.

When a new rule is proposed, check it against these principles. When the project owner states a new standing principle ("I want things to be like this"), add it here at the end, with the date and his reasoning in his own words where possible.

Status tags are the same as in `DESIGN_IDEAS.md`: [Decided], [Idea], [Proposed], [Open].

## 1. Safe, kind, generous, in that order

- **[Decided]** (2026-10-11) People in the game should be safe first, then kind, then generous. If you cannot be generous, be safe and kind. If you cannot be kind, at least be safe. If you cannot manage all three, remove yourself from the situation.
- **[Decided]** What this means for design: systems for safety (protection from abuse, ways to leave a bad situation), kindness (rescue, understanding, second chances) and generosity (gifts, charity, adoption, helping struggling dynasties) are core design, not extras. When two rules conflict, the one that keeps people safer wins, then the kinder one.
- **[Decided]** Examples already in the game: the temple (Section 8.11 of `DESIGN_IDEAS.md`), rescue before death, the safety valve that stops a failing town from falling into a death spiral, and PvE areas where nothing can be hurt.

## 2. Do it yourself, or hire it out

- **[Decided]** (2026-10-15) You can do anything in the game yourself, and you never have to. If a player loves cutting down trees, they can cut down trees all day. If they do not want to, they can hire an NPC to cut the trees for them.
- **[Decided]** Why: players come to the game to enjoy a particular style of play, not to be forced through every chore. Handing a job off lets people spend their time on the parts they like, and keeps their dynasty running while they are away. Every kind of work should therefore work both ways: by hand for fun, or delegated to family or hirelings.
- **[Decided]** What this means for design: no job may be possible only by hand, and no job may be possible only through NPCs. Doing it yourself pays more, and delegating costs a cut but keeps things running, so neither route is a trap.
- The matching game rule is "No micromanagement" in `DESIGN_IDEAS.md` Section 3, kept as it is.

## 3. Nobody is forced to build a town

- **[Decided]** (2026-10-15) A player must never be forced to build a town or settlement to get the full dynasty experience. A player can woo a spouse, raise a family and run a dynasty with no fixed home at all, travelling together and living out of a ship, or a wagon with tents. Whenever they want to settle down, even for a while, they pick a spot and put down a tent, as with a camp.
- **[Decided]** Why: the game is about playing the way you like (Section 3 of `DESIGN_IDEAS.md`, "Play what you like"), and town building is only one style. Towns, homesteads and nomadic life are equal choices.
- **[Decided]** What this means for design: before adding a system, check that it does not quietly require a fixed home, a farm or a town. Anything a household needs (a bed, food, childcare, safe logout) needs a version a travelling family can use.
- The concrete design question this raises is logged as an open item in `DESIGN_IDEAS.md` Section 15 (the nomadic household).

## 4. Content, visuals and sound count equally

- **[Decided]** (2026-10-17) Content, visuals and audio get equal attention. Older games leaned on content and neglected how they looked and sounded. Visuals have since become amazing, and in a few games sound has become a main focus.
- **[Decided]** Why: our brains react faster and more strongly to sound. A full, layered sound stage lets a player close their eyes and believe they are in the world. Inspiration: theHunter: Call of the Wild, where much of the play is listening (ducks, waves on the water, a gentle breeze, a stick cracking, squirrels chirping, birds calling) and some players fall asleep to it with headphones on.
- **[Decided]** What this means for design: when adding a system, ask what it looks like and what it sounds like, not only what it does. Audio has its own performance budget (`ARCHITECTURE_BUDGET.md` Section 9). This is a direction; no audio is being built yet.

The original wording is also in `DESIGN_IDEAS.md` Section 3. How the two documents should relate (whether the copy in Section 3 stays or becomes a pointer to this file) is [Open] until the project owner reviews it.
