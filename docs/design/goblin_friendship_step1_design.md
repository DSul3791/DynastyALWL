# Goblin friendship, step 1: trust, gifts, Tolerated and Known (design)

Steve, 8 Nov 2026. This is the first build step of `goblin_ally_design.md` (#586), which Dave agreed to on 8 Nov 2026 (decision 7: "yes, slowly"). It stands on goblin den life (#597) and stealing (#602). **Runtime only, no rebake, no protocol change.** Step 2 (Trusted: the warning whistle and safe den entry) needs a client sound event, and comes after.

## 1. Rules in this step

- **The band** is the goblins of one cave: the mouth's lair key (`"x,z"`, already on each goblin). Trust is held per band and per player character (`server_items.key_of(peer)`).
- **A gift:** a thing a player dropped (`by`, the dropper's character key, now kept on the loose item while the server runs) that a goblin of the band takes in the dark. Stealing and taking a gift are the same act (`goblin_stealing_design.md`).
  - It counts **once per game night**, per band and player: +1 trust.
  - A night runs from noon to noon, so a night that crosses midnight counts once.
- **Steps:**
  - **Tolerated, at 3.** The band no longer runs from that player at `spook_m` (30 m). It watches them openly, and runs only inside `watch_spook_m` (6 m).
  - **Known, at 7.** The band **stops stealing** that player's things. It still takes the **food** they leave, since food is a gift. A goblin that watches at a fire where a Known player is nearby leaves a **return gift** at its watching spot when it goes: once per game day, per band and player, from `return_gifts`. The items are existing ones (dried berries, flint, a feather, a bone), and the table is data, so it can change when new items come.
- **Harm:** hitting a goblin of the band (`damage()` with the player as source) sets that player's trust to 0. The band is then **wary** for `wary_days` game days: in that time it runs from that player at twice `spook_m`.
- **Forgetting:** trust falls by 1 for every `forget_days` game days without a gift. It is worked out when read, so no timer is needed.
- **Saved** in `goblin_trust.json` in the server's store folder, as `{band: {character: {trust, last_gift_s, wary_until_s, night, gift_day}}}`. Game seconds come from the server clock. It is written at most every 30 s when changed.
  - A band whose mouth moves after a rebake has a new key, so its old records just sit idle. A record that has forgotten down to 0 and is not wary is dropped.

## 2. Changes from `goblin_ally_design.md`

- **Data:** in `animals.json`, the goblin's `ally` block, next to `den_life`. The design said `data/creatures/goblins.json`, but that file only holds the looks, and the server reads `animals.json`.
- **Keys:** the band key is the mouth's lair key, not a tile and cave id. It is stable for as long as the cave is, and cave ids move with rebakes anyway.
- **Return gifts:** existing items only. `shiny_stone` and `bone_needle` wait for Kathleen's art and the item rows.
- **Deferred:** taking from the den and carrying light into the den also count as harm, and they come with step 2. They need pickup and torch hooks, at the den.

## 3. Data

`"ally": {"steps": {"tolerated": 3, "known": 7, "trusted": 15}, "forget_days": 7, "wary_days": 5, "return_gifts": [{"item": "dried_berries", "weight": 4, "count": 3}, {"item": "flint", "weight": 2, "count": 1}, {"item": "feather", "weight": 2, "count": 2}, {"item": "bone", "weight": 1, "count": 1}]}`

## 4. Systems touched

| file | change |
|---|---|
| `server_goblin_trust.gd` (new) | the trust records: gift, harm, step, wary, load and save |
| `server_goblins.gd` | the Known filter on stealing (food only), Tolerated and wary spook distances, the gift count on a take, the return gift after a watch |
| `server_items.gd` | `by` on a player's drop (kept in memory, not saved); `stealable_near` rows carry `by` and the item kind |
| `server_animals.gd` | harm in `damage()`; the trust module's tick |
| `terrain_server.gd` | wiring: `key_of`, game seconds, the store folder, `drop_in_world` for return gifts |

## 5. How we know it works (headless on the PC)

`test_goblin_friendship.gd`:
- gifts on 3 nights reach Tolerated, and two in one night count once;
- a Tolerated player 20 m away is watched, not fled from;
- at Known, a tool dropped by that player is not taken, their food is, and another player's tool is;
- a watch near a Known player leaves one return gift a day;
- a hit resets trust to 0 and makes the band wary, running at twice `spook_m`;
- trust forgets 1 per `forget_days`;
- the records survive a save and a load.

## 6. Must not break

- Goblins never enter light, at any step.
- Other players are still stolen from.
- No band follows a player.
- Cornered goblins still fight.
