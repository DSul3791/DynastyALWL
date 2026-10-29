# NPC system design (draft 1, design only, send to Steve before any code)

Dave 2026-10-21: all voices will eventually be AI driven, but first build the classic NPC system and let it switch between classic and AI, so the game still works when the AI is down. When the AI cannot connect, NPCs act unwell and keep talk to a minimum: "I apologize, I have had a headache all day", then a small detail or instruction, then back to bed or chair. Voice is text to voice (Mandy hooks it up; lines stay data, no recordings planned). Fits DESIGN_IDEAS: the game owns the facts, the model only speaks (118); rules drive routine work, the model handles conversation; materialise from schedules, simplified at range (107). Follows Tyler's NPC entry in BEST_PRACTICES.md. Nothing here has been looked at by eye (no code yet).

## 1. Pieces
1. **NPC record** (server): id, name, role, home town/tile, persona id, voice id, bed marker, chair/work markers, schedule table, flags per player (met, helped, owes), state (sleeping, sitting, working, walking, talking, unwell).
2. **Schedule runner** (server): picks one active package per NPC from a 24-hour table, walks it to a marker, places dormant NPCs on activation.
3. **DialogueProvider interface** with two providers, **StaticProvider** (always on) and **AIProvider** (later, async), and a **Router** that picks between them.
4. **Dialogue UI + voice** (client): a text box with the line, the NPC's name, choices, and a hook that hands the line to text to voice (Mandy).

## 2. Provider interface (what AI will plug into)
`get_line(npc_id, player_id, context, player_input) -> {text, source, voice_id, actions, end_talk}`
- `context` is built by the server from truth: NPC role and persona, time of day, weather, the player's flags with this NPC, open quests, what the NPC may sell or give, the last few turns. The provider gets no more than this.
- `source` is "static" or "ai" (logged, and shown to nobody).
- `actions` may only come from a whitelist the server validates (open trade, give a quest line already authored, walk away). The AI can never grant items or invent facts.
- Same `voice_id` and name whichever provider answered, so the switch is invisible except in tone.
- Providers are called off the server tick (a worker queue); the player sees a short idle "thinking" animation, never a freeze.

## 3. Router and health
- Call AI if healthy, else Static. Per call timeouts: first token 1.5 s, total 4 s; on timeout use Static for that line.
- Circuit breaker: 3 failures in 30 s opens it for 60 s; a cheap health probe every 30 s closes it. Switch is instant both ways. Log which provider answered.
- Admin switch in the admin tool: Auto, Force static, Force AI (for testing). Default Auto, and until an AIProvider exists Auto means Static.
- AI safety (when it exists): input cap 200 characters, 1 message per 3 s per player, daily token budget per player and a session budget per NPC, moderation of input and output, persona and rules server-side only, the AI is called only when a player addresses the NPC.

## 4. Fallback mode: the unwell NPC
When the Router is on Static because the AI is down (an "AI outage" flag), the NPC is flagged **unwell**. This reads as in-world, not as a bug.
1. On talk: a **complaint line** (random from a pool of 8 to 12, none repeated within the last 5), e.g. "I apologize, I have had a headache all day." "Forgive me, my head is pounding." "I am not myself today."
2. Then **one or two short info or instruction lines** from the NPC's authored data (a quest hint, where the market is, what they sell, a warning). Never more than two.
3. Then the NPC **ends the talk** ("Now, if you will excuse me...") and walks to its bed or chair (nearest free marker), plays the unwell idle (hand to head, slower walk), and goes back to sleep or sits.
4. **Talk cooldown** 2 to 5 game minutes after a fallback talk (the NPC says only a short bark, "Please, later.").
5. Trade and quest actions that are plain data (open shop, accept a quest) still work through buttons; the NPC says them in one short line. Only free conversation is withheld.
When the AI is healthy no NPC is unwell and talk is normal (static trees still work as the shape for authored quest dialogue).

## 5. Static dialogue data (data/npcs/dialogue/*.json)
- **Barks:** greeting, farewell, idle, complaint (unwell), cooldown, per role and time of day.
- **Trees:** nodes `{id, text, conditions, choices:[{text, goto, effects}], effects}`. Conditions read flags, items, time, weather, season, quest state. Effects: set flag, give quest, open trade, end talk, walk to marker. Line ids are stable and localisable; a line is voiced by hashing its text into the audio id so edited lines regenerate.
- **Topics** keyed to quest and item ids, so a new item or quest adds a line without rewriting the tree.
- Lines up to 12 words per spoken sentence (Tyler's TTS note).
- **Validator** (extends validate_items): every node reachable, every goto exists, every effect and condition valid, no dead ends, no line over the cap, every NPC has a complaint pool of at least 8.

## 6. Schedules (data/npcs/schedules/*.json)
- Radiant-style: a 24-hour table of hourly slots, each naming a package: sleep, sit, work, eat, wander, shelter. One package active at a time.
- Packages run at **markers** placed in the world (bed, chair, workbench, market stall, door), each with slots so two NPCs never take one chair. Markers come from the starter-town placement data.
- ±10 minute jitter per NPC so the town does not move as one.
- Weather and night override: shelter in rain, bed at night, a fire in cold.
- **Dormant NPCs** (no player within about 200 m) are not simulated; when a player comes in range the NPC is placed at the marker its schedule says for the current time (lazy resolution). Walking between markers is only simulated within sight.
- A talk interrupts the package and resumes it afterwards. An unwell NPC always resumes at bed or chair.

## 7. Server cost at 20 players
- NPC records are tiny (about 200 bytes). A starter town of 30 NPCs costs nothing when dormant.
- Active (in range) NPCs: at most 30 per player and 60 total simulated. Walk at 2 Hz far, 10 Hz near, with the same steering as animals (shared code), roughly 5 to 20 microseconds each: well under 0.5 ms per tick.
- Static talks cost a table lookup. AI talks run on a worker queue with a hard queue length (20); beyond it the Router answers Static. Tyler's estimate when AI exists: about 2 calls/s and 4 M tokens/hour at 20 players, so a small model and cached common replies.
- Network: NPC position/heading/state for NPCs within 120 m at 4 Hz, about 12 bytes each, delta sent: under 2 KB/s per player in a busy square. A dialogue message is one small RPC per line. New RPCs `npcs(numbers)`, `npc_say(npc, text, voice, choices)`, `npc_talk(npc, choice)`: protocol bump when built, cost at Low stated then (draw the same ragdoll body as the player, max 20 NPCs drawn).

## 8. Saving
- Per NPC per player: flags, the last 6 turns and a summary of up to 300 tokens (only when AI is on), versioned and capped, decaying. Flags are the same ones the static trees read, so switching keeps continuity.
- Schedules and markers are data, not saved. NPC positions are not saved (placed from the schedule on activation).
- Neutral default: no NPCs, so old saves load unchanged.

## 9. Build order (each its own push, each approved)
A) NPC record, markers and the schedule runner with two test NPCs (a shopkeeper and a guard) walking to bed and chair; admin spawn; stress at 20 players.
B) StaticProvider, dialogue data, validator, dialogue screen; barks and one quest tree.
C) Router, health flag, fallback unwell mode, admin switch, a test that forces an outage.
D) Text to voice hook (Mandy), voice ids per NPC.
E) AIProvider stub behind the interface (no model), with budgets and moderation hooks; real model later.

## 10. Questions for Steve (not Dave)
- Where do the starter-town markers (beds, chairs, stalls) come from: the town placement data, or hand placed by admin? I recommend admin tool placement saved to data, so the town designer can move them.
- NPC body: reuse the player ragdoll with a clothes set for the first wave. I recommend yes.
- Quest data does not exist yet. For step B, the info lines can come from a small hand-written list per NPC until it does.


## Admin check (2026-10-21, build 459)
data/items/admin_setting.json "check_admin" is the one switch. false (default, local play): everybody is an admin, so X digging, NPC markers and the Admin build list work with no admin.json or player key. MUST be set true before any public server; then only keys in data/admin.json are admins and ACT_ADMIN_GIVE is refused for the rest. The allow-list code and tests stay in place.


## Step C: router and unwell fallback (build 466)
src/stream/dialogue_router.gd sits in front of the static provider (and a future AI provider). Breaker: 3 failures in 30 s open it for 60 s, one probe every 30 s; unwell shows only after the breaker has been open 10 s and any shown mode holds at least 60 s (anti-flap). Unwell NPCs sit in a chair by day (6-21) and sleep otherwise (ServerNpcs.unwell), say one complaint plus one or two "info" lines from their own dialogue file, then rest 2-5 game minutes (cooldown line) before talking again. Test switch: start the server with --npc-ai=down (also auto, static, ai). Per-role pools live in each NPC's dialogue file (barks complaint, info, cooldown).
