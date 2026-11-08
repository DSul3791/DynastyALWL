# Bear threat: stand, huff, jaw-pop, bluff, charge (design)

Steve, 8 Nov 2026. This is guiding document section 7.1, card "Bear at den", which #550 correction 4 made a **Proposal**. **Dave agreed to it on 8 Nov 2026** ("I agree to all recommendations", section 9), so it may now be built. The coordinator's build order puts it first after goblin den life. It covers both bears: the brown bear (species 14) and the black bear (species 18).

## 1. Today [Existing]

- **Den** (`animals.json` bear `den`):
  - The den ring is 15 m. Anyone inside `den.threat_m` 15 is threatened.
  - A torch does not protect you at the den. Outside the den, a fire's or torch's keep-off radius does (`server_animals.gd` `_in_den` and `_fire_guard`).
- **Warning and charge** (`server_big_game.gd`):
  - **WARN** (state 10): the bear faces the player for `warn_s` 1.5 s, or 0.8 s when threatened or cornered. The client plays `IdleAngry_Breathing_01`.
  - **CHARGE** (state 11): 12 m/s for up to 25 m. It turns only 0.35 rad/s, so a step aside dodges it. A hit does 35 damage.
  - **RECOVER** (state 12): 4 s.
  - **Backing off:** a player who backs past `calm_m` 30 during the warning is not charged.
- **Alert:** the bear stands on its hind legs (clip `IdleHind_Idle_01`, `models.json` "Alert stands up").
- **Seasons and young:** spring threat x1.5, and autumn threat x0.7. A mother attacks at once when a player is between her and a cub (`young.between_m`).
- **Temperament:** defensive 0.6, neutral 0.25, aggressive 0.15.

## 2. What real bears do (research)

- **Standing up** is curiosity, not threat: the bear wants a better look or smell. Huffing, woofing, **jaw-popping** (teeth clacking), ground slaps and stomps are signs of stress.
- **Bluff charges** are common, and the bear stops short or veers off.
- **Running away** can trigger a chase. The advice is to stand, talk, and back away slowly while facing the bear.
- Sources: [NPS, bear attacks](https://nps.gov/articles/bearattacks.htm); [NPS Katmai, bear encounters](https://www.nps.gov/katm/planyourvisit/bear-encounters-in-katmai.htm); [BearSmart, communication](https://bearsmart.com/about-bears/communication).

Our pose today has it backwards: the standing bear is already the *alert* pose, which is right, but it reads to a player as the threat. The design keeps stand = curious, and makes the threat a ladder the player can read.

## 3. The ladder [Proposal]

A bear goes up one rung at a time. Each rung is a visible and audible cue, so the warning contract of section 8.3 holds. The player can stop the ladder at any rung by backing off past `calm_m`.

| Rung | When | Cue | Server state |
|---|---|---|---|
| 0. Curious | Notices a player within `alert_m` 50, outside the den | Stands on hind legs, nose up (`IdleHind`) | ALERT (exists) |
| 1. Stressed | Inside `defend.threat_m` 9, or inside the den ring, or a cornered or mother case | Drops to four legs, **huffs**, faces the player | WARN, first half of `warn_s` |
| 2. Final warning | The player is still inside `calm_m` | **Jaw-pop** and a ground swat or stomp | WARN, second half |
| 3. Charge | WARN runs out | Sprint at the player | CHARGE. With `bluff_share`, a **bluff**: it stops short at `bluff_stop_m` and then recovers |
| 4. Contact | A real charge reaches `hit_m` | Swipe | CHARGE hit (exists) |

**Running makes it worse.** A player who runs (sprint speed) during rung 1 or 2 skips the rest of the warning: it goes straight to rung 3, and that charge is never a bluff. This is the one new rule that teaches the real-world advice.

**The den keeps its own rule.** Fire still does not help inside the den ring, and the bluff share is halved there. A mother between her and her cubs never bluffs.

## 4. Data (all in the existing `defend` block; new keys are optional and default to today's behaviour)

```jsonc
"defend": { ...today's keys...,
  "huff_share": 0.5,          // share of warn_s spent on rung 1 before the jaw-pop
  "bluff_share": 0.6,          // chance a charge is a bluff (scaled by temperament: defensive x1.2, aggressive x0.5)
  "bluff_stop_m": 4.0,         // a bluff stops this far from the player
  "den_bluff_x": 0.5,          // bluff share inside the den ring
  "run_trigger_mps": 6.0       // a player moving faster than this during WARN skips to a real charge
}
```

Black bear: a higher `bluff_share` (0.75). Black bears bluff more and rarely press home.

## 5. Systems touched

1. **`server_big_game.gd`:**
   - WARN carries a `phase` (huff, jaw-pop), sent as the animal's state byte. Either a new state 13 (WARN_POP), or WARN keeps its number and the client times the jaw-pop from `huff_share`. I recommend state 13, so the server stays the single source.
   - CHARGE gets a `bluff` flag that ends it at `bluff_stop_m` without a hit.
   - The run trigger reads the player speed that `player_info` already carries.
2. **`src/client/animal_view.gd`:** maps the clips of the new phase. MikeW picks the clips from the bear's 81 (huff, jaw-pop, swat or stomp) and the black bear's 136. `models.json` `clips` gets key "13".
3. **Sounds (Jason):** a huff, a jaw-pop and a woof, played on state change. Two growl recordings exist in the shared folder (`bear_01_growling…`, `bear_02_growling…_needs_trim`); they are growls, not huffs. These are QA listening items (Dave listens).
4. **The interaction card (`cards.json`, #550):** the warning cues move from `built: false` to built as each one lands.
5. **Journal (#547):** watching a full ladder without being hit counts as an **Observed** event for the bear.

## 6. How we know it works (David4 headless, then Dino on the PC)

- **Headless test (`test_bear_threat.gd`):**
  - A scripted player walks into the den ring, and the states run 10 → 13 → 11.
  - Backing off during 10 or 13 ends in calm with no charge.
  - Sprinting during 10 skips to a real charge.
  - With `bluff_share` 1, the charge ends at `bluff_stop_m` with no damage.
  - A mother with cubs never bluffs.
  - Old rows without the new keys behave exactly as today.
- **On the PC:** a picture or clip of each rung, the huff and jaw-pop sounds, and 0 shader errors.

## 7. Must not break

- Every attack stays dodgeable.
- A torch still does not protect at the den.
- The goblin rule still holds: goblins never den within 120 m of a bear (`lair.avoid_m`).
- The moose, boar and goblin share `server_big_game.gd`. They get the new keys only if their rows add them, so with no row change their behaviour is unchanged.

## 8. Depends on

- ~~Dave's reaction to this design~~: given 8 Nov 2026 (section 9).
- **MikeW:** the clip mapping for state 13.
- **Jason:** the huff and jaw-pop sounds.

It needs no rebake and no water or terrain work.

## 9. Decided by Dave (8 Nov 2026)

Dave answered the coordinator's questions with "I agree to all recommendations". For this design that means:

| # | question | decided |
|---|---|---|
| 1 | Should a bear warn in steps before it charges (stand up curious, huff, jaw-pop, charge, some charges stopping short as a bluff)? | **Yes**, the ladder in section 3 |
| 2 | If a player runs while the bear is warning, does it skip the rest and charge for real? | **Yes** (`run_trigger_mps`): it teaches backing away slowly |
