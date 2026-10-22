# AI provider contract for live NPC talk (Radar, 2026-10-21)

Nothing here needs a build. The code is in place and tested with a stub: `src/stream/ai_guard.gd` (request builder and the one door every AI line passes), `src/stream/stub_ai_provider.gd` (canned text through the same path), `data/npcs/ai_rules.json` (every limit), `src/worldgen/tools/test_ai_contract.gd` (11 checks, registered as `ai_contract`). To plug in a real AI: write one provider class that extends `dialogue_provider.gd`, set `dialogue.router.ai = it`. Nothing else changes.

## 1. The rule that keeps it simple
An AI line and a prebaked line are the SAME dictionary. The speech path (voice trial: text in, per-client cache by voice, speed, pitch, model and text, settings Off / Premade only / Live) never asks where a line came from. `source` is only for logs and the settings switch.

Line shape (both kinds):
`{text, source "static"|"ai", voice_id, choices [String], map [node ids], node, end, effects [..]}` plus three optional fields the speech path reads: `speed` (1.0), `pitch` (1.0), `mood` ("neutral"). Static lines may omit them. The wire to the client carries text, voice id, speed and pitch (a protocol bump when the voice trial starts; mood stays on the server and only picks speed and pitch for the AI).

## 2. What the game sends the AI (`AiGuard.build_request`)
```
{version 1,
 npc: {id, name, role, persona (short, from data), voice_id},
 memory: last 6 lines said between this player and this NPC (text only),
 flags: names of the flags this player has with this NPC,
 world: {hour (game), facts: up to 8 short strings: weather word, who else is near, what the NPC is doing},
 allowed_actions: the actions the server would accept RIGHT NOW (exact effect dictionaries, e.g. {"set_flag":"ai_friend"}),
 player_line: the chosen button text, or typed text later (200 chars max)}
```
Never sent: other players' names, keys or positions, inventory, the admin key, anything about the server. The AI cannot see or change game state; it only returns a reply.

## 3. What must come back
`{text, mood?, speed?, pitch?, choices? [up to 4 short labels], end?, effects? []}`.
- `text`: one NPC speaking in character. Max 320 characters and 60 words.
- `mood`: one of neutral, warm, cheerful, gruff, worried, angry, sad, amused (else neutral).
- `speed` 0.85 to 1.15 and `pitch` 0.92 to 1.08, clamped. Voice id is always the NPC's own; a provider cannot choose another voice.
- `effects` (action tags): kept only if the same dictionary was in `allowed_actions`, at most 2 per line. So the AI can say "I'll give you the axe" but the item only moves when the server offered that exact give and its own conditions hold. Free item or skill grants are impossible.
- Choices from an AI are plain labels; the server maps each to node "ai" so the next click asks the AI again with that label as `player_line`.

## 4. Safety limits (hard: the line is dropped and counts as a failed call)
Empty text, over length, control characters stripped, banned text (links, "as an AI", model and company names, listed in ai_rules.json). Soft: clamps above. The AI also gets a short system prompt from data saying: stay in a medieval fantasy world, never mention being an AI, never give real-world advice, keep it to two sentences. The prompt is a request, the guard is the enforcement.

## 5. Timeouts, breaker, unwell fallback (already built, router)
- Timeout per call: 6 s (`timeout_s`). A late reply is a failed call. The player sees the NPC "thinking" for at most that long; the static provider answers instead if it is exceeded.
- Breaker: 3 failures in 30 s opens it for 60 s; one probe every 30 s while open; a good probe closes it.
- After the breaker has been open 10 s the town is "unwell": each NPC gives one complaint and one or two small facts (authored per role), goes back to a bed or chair, and rests 2 to 5 game minutes before talking again. The shown mode holds at least 60 s so a hiccup never flaps the town. Admin switch `mode`: auto, static, ai, down.
- Sleeping NPCs never call the AI (they mumble from data).

## 6. Cost per line
About 450 prompt tokens (persona 150, memory 150, context 100, player 50) and 60 reply tokens. At a small-model price that is a small fraction of a cent per line, so 120 live lines per player per game day (`lines_per_player_per_day`) is cents per player per month. Over the limit the player gets prebaked lines for the rest of the day. Prebaked lines stay the default: live talk is only on when the setting is Live and the provider is healthy.

## 7. Decisions still open (not mine)
Which AI provider and key storage; whether typed player lines are allowed (needs a profanity pass on the way in); memory persistence across sessions (today the server keeps only flags); whether live mood should also drive the NPC animation.
