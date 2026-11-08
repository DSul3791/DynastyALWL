# Goblin Ally: earning a band's trust (design)

Steve, 8 Nov 2026. This is guiding document section 7.1, the goblin band card's "Ally". #550 correction 2 made it a **Proposal**, because Dave's `docs/GOBLINS.md` describes skittish night thieves only. **Dave agreed to it on 8 Nov 2026** ("I agree to all recommendations", section 9), so it may now be built, after stealing. **Nothing in it changes what goblins are.** They stay skittish thieves who keep out of light. Ally changes only how one band treats one player.

## 1. Today [Existing]

- **Bands and dens:**
  - A band is a group of 2 to 5 (species 16, `lair.group`).
  - Its den is the dry dead end of a spring cave side branch, or of a karst cave or lava tube (#543), with bones, sticks, thatch and a small fire.
  - **A band never dens within 120 m of a bear** (`lair.avoid_m`), and respawns after 30 min (`lair.respawn_s`).
- **Behaviour:**
  - Active at night (night 1.0, dusk 0.5, day 0).
  - Watches from 60 m (`alert_m`) and runs at 30 m (`spook_m`).
  - Keeps out of fire, torch and lamp light.
  - Fights only when cornered or threatened at its den (`defend`: den ring 12 m, threat 8 m, 8 damage).
- **Not built:** stealing, berry foraging, sneaking to the edge of firelight on purpose, a goblin whistle or footstep sound, a goblin sign row.
  - Dave decided how much they steal, where stolen things go and whether they drop them when killed on 8 Nov 2026 (section 9).

## 2. The idea [Proposal]

Goblins are thieves who watch people from the edge of the firelight. Ally turns that watching into a slow relationship. A player who **leaves gifts at the edge of the light and does them no harm** becomes known to that band.

The band still never comes into the light, never follows the player and never fights for them. What changes:
- they stop stealing from that player;
- they leave things in return;
- they warn of danger at night.

It is the same **approach, offer, wait, bond** shape as taming (G-09), but the trust belongs to the **band**: one den and one player's character.

## 3. Trust steps

| Step | Trust | Earned by | What the band does |
|---|---|---|---|
| Stranger | 0 | (start) | Today's behaviour, plus stealing once it exists |
| Tolerated | 3 | Gifts taken on 3 different nights | Watches openly at the light's edge instead of fleeing at `spook_m`; a soft whistle when it notices the player |
| Known | 7 | 7 nights of gifts, and no harm | **Stops stealing** from this player and from their camp. Leaves a **return gift** by the fire's edge before dawn, from a table: berries, a shiny stone, a lost tool, a bone needle |
| Trusted | 15 | 15 nights, and has seen the player defend themselves from a bear or wolves at night | **Warns:** a sharp whistle when a bear or a wolf pack is within 60 m of the player at night. The player may enter the band's den branch without the den's threat ring firing, as long as they carry no light into it |

- **What counts as a gift:** food or a small object left on the ground at night, outside every light, within 40 m of where the band watches. The band takes it unseen: it vanishes while no player looks within 15 m. Stealing and taking a gift are the same act, so this needs the stealing system first.
- **Harm resets trust to 0** and marks the band **wary** for `wary_days` game days, during which it flees at twice `spook_m`. Harm means hitting or killing one of the band, taking from its den, or carrying light into the den.
- **Forgetting:** −1 trust for each `forget_days` game days with no gift.

## 4. Data

- **`data/creatures/goblins.json`**, a new block, `"ally"`:

```json
{ "steps": [{"name": "tolerated", "trust": 3}, {"name": "known", "trust": 7}, {"name": "trusted", "trust": 15}],
  "gift_reach_m": 40.0, "gift_unseen_m": 15.0, "per_night": 1, "forget_days": 7, "wary_days": 5,
  "return_gifts": [{"item": "berries", "weight": 4}, {"item": "shiny_stone", "weight": 2}, {"item": "bone_needle", "weight": 1}],
  "warn_m": 60.0, "warn_kinds": ["bear", "wolf"] }
```

- **The save, `goblin_trust.json`:** `{band_key, character_key, trust, wary_until_s, last_gift_s, history}`.
  - The band key is the den's tile and cave id. Animals are not saved, but a band is tied to its den, and the den comes from the world.
  - **After a rebake**, a den whose cave id is gone takes its bands' trust with it. The record is kept, marked `moved`, and dropped after 30 days. Cave ids are stable only within one record version (Stage E section 3).
- Items `shiny_stone` and `bone_needle`: new rows in the item tables, if they don't exist. Kathleen does the art.

## 5. Systems touched

1. **Stealing (not built).** It is the base this stands on. Dave answered its questions on 8 Nov 2026 (section 9); it gets its own design note before code.
2. **`server_animals.gd` goblin behaviour:**
   - "watch openly" at Tolerated;
   - gift pick-up while unseen;
   - the return-gift drop before dawn;
   - the warning whistle, which reads nearby bears and packs.
3. **Den threat:** `_in_den` skips the den ring for a Trusted player who carries no light.
4. **Sounds (Jason):** the soft whistle and the warning whistle. The interaction card lists the whistle as a cue; today `goblin_step` borrows the wolf's sound.
5. **Journal (#547):** Ally steps are **Observed** events for goblins. The goblin page records the band and its step.
6. **Signs (#551):** the return gift is itself a goblin sign ("something left by the fire").

## 6. How we know it works

- **Headless test (`test_goblin_ally.gd`):**
  - gifts on 3 nights reach Tolerated;
  - two gifts in one night count once;
  - at Known, stealing skips this player and still takes from another;
  - harm resets trust and sets wary;
  - a Trusted player in the den branch with no torch is not charged, and with a torch is;
  - the trust record survives a save and load;
  - a missing den marks it `moved`.
- **On the PC:** a picture of a return gift by a fire at dawn, the whistle, and 0 shader errors.

## 7. Must not break

- **Goblins never enter light**, at any step.
- They stay skittish and night-active.
- They never share a cave with a bear.
- They fight if cornered: being Trusted doesn't make cornering safe.
- Other players are still stolen from.
- No band follows a player or fights for one. Those are companions (G-09), which goblins are not.

## 8. Depends on

1. ~~Dave's reaction~~: given 8 Nov 2026 (section 9). Goblins may become friendly, slowly.
2. **The stealing system**, built to Dave's answers in section 9.
3. **Jason:** goblin whistles.
4. **Kathleen:** the return-gift item art.

It needs no rebake and no water or terrain work.

## 9. Decided by Dave (8 Nov 2026)

Dave answered the coordinator's questions with "I agree to all recommendations". For goblins that means:

| # | question | decided |
|---|---|---|
| 7 | Can goblins ever turn friendly to a player? | **Yes, slowly.** Gifts left outside the firelight over many nights make that band stop stealing from that player, leave small gifts back, and whistle when a bear or wolves come near. They never enter light or follow anyone |
| 8 | How much do goblins steal? | **One small item at a time**, only from what no fire, torch or lamp lights |
| 9 | Where do stolen things go? | **Into a pile in their den**, where a player can find them and take them back |
| 10 | Does a killed goblin drop what it stole? | **Yes**, what it is carrying |
| 11 | Is each goblin's height roll saved? | **No.** It comes from the animal id, so it is always the same |
| 12 | Do foraging goblins strip berry bushes? | **No, for now.** They eat without changing the bush |
| 13 | What stops a killed group coming back? | **A lit building or a player camp with a fire within 100 m of the cave mouth** (`lair_guarded`) |

Build order (coordinator, 8 Nov 2026): den life first, then stealing and the den pile (8, 9, 10, 13), then this design (7).
