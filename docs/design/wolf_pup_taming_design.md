# Wolf pup taming: the first Companion bond (design)

Steve, 8 Nov 2026. This is guiding document section 7.1 (wolf card "Tame (pup)") and section 8.2 (G-09 taming, the Companion bond). #550 correction 3 made it a **Proposal**. Taming order D-03 puts the companion first. **Dave agreed to it on 8 Nov 2026** ("I agree to all recommendations", section 10), so it may now be built, after the dog companion (section 6).

## 1. Today [Existing]

- **Wolves** are ordinary animal records (species 3) driven by a pack brain, `server_wolves.gd`. The pack rows are in `animals.json` `wolves`. Packs:
  - are 3 to 5 strong, with a den at `den_m` 300 and a hunger cycle;
  - keep out of fire light (10 m) and torch light (9 m);
  - steal meat (`steal_bites` 3);
  - break when two players or a wolf kill scare them.
- **Wild packs are off** (`wolves.natural: false`), so packs come only from the admin spawn.
- **There are no wolf young.** Other species have a `young` row (share, count, `follow_m`, seasons), and the young follow their mother through the existing young-follow code.
- **Horses** have a born tamable value (0 to 1) that sets how close you can come and when one gets curious (`tame` row, `server_animals.gd` `_spook_m` and `_curious`). There is no bond, owner or record yet.
- **The companion record is designed and not built:** #547 section 5, `companions.json` `{id, species, name, born_s, level, traits, bond, owner_key, history}`. It passes to an heir with a bond share. It is spawned near its owner and never by the wild spawner, and it follows using the young-follow code.

## 2. Research

- Wolf pups start exploring at about 2 weeks old, while still blind and deaf, so they meet the world by smell first. Pups that are not handled from about 10 days old with near-constant contact stay wild.
- Even hand-raised wolves stay more independent than dogs, and adults are never tamed. Source: [ScienceDaily, 2013, "Why wolves are forever wild, but dogs can be tamed"](https://www.sciencedaily.com/releases/2013/01/130117152012.htm).

The game keeps that shape: **only a pup, only an orphan, and only by days of care.** A raised wolf is a wary, loyal companion, not a dog.

## 3. How it plays [Proposal]

1. **Pups exist.** In spring, a pack with a den has 2 to 5 pups at the den, which stay within `follow_m` of an adult. The pack defends its den harder than today: the existing `den_notice_gain` and `den_weak_gain` already make a pack bolder there.
2. **Only orphans can be taken.** A pup can be approached only when its pack is gone: killed, or driven off and not returned within `orphan_s`. You never take a pup from a living pack. A pack that sees a player near its pups rushes at once, torch or not, the same way a mother does for young.
3. **Approach, offer, wait, bond** (G-09's verbs):
   - **Approach:** crouched and slow. An orphan hides in the den, and standing or moving fast scares it back.
   - **Offer:** place raw meat or fish on the ground within 3 m and back off. The pup eats when you are more than `trust_gap_m` away. Each meal adds trust, at most one a game day.
   - **Wait:** after `trust_to_follow` days of meals, the pup follows you. It is now a **companion**: a record is written, you name it, and the bond starts at 0.1.
4. **Raising.**
   - The bond grows by `trust_per_day` for each game day you are near it and it is fed.
   - It falls when it goes hungry. At bond 0, the wolf leaves and goes wild again; the history records "lost".
   - It grows to adult over `grow_days` and then has the adult wolf's numbers.
5. **What a companion wolf does** (bond-gated, one ability a step):

| bond | ability |
|---|---|
| 0.1 | follows; stays out of fires (the wolf rule); never steals from its owner |
| 0.3 | **warns**: growls when a hostile creature (wolf pack, bear, goblin) is within `alert_m` of its owner |
| 0.5 | **stays** and **comes** on command |
| 0.7 | **hunts** small game (rabbit, grouse) and brings the kill |
| 0.9 | **guards** the owner: it bites a creature that attacks the owner, using the wolf bite numbers |

6. **Heirs:** the companion passes to the heir with `inherit_bond_share` of its bond (#547 section 5). That is the dynasty link of section 8.2.

## 4. Data

- **`animals.json` wolf:**
  - a `young` row (spring, count [2, 5], `follow_m` 3, `hp_x` 0.25);
  - a `tame` row in G-09's shape: `{bond: "companion", only_young: true, only_orphan: true, food: ["raw_meat", "raw_fish"], trust_to_follow: 3, trust_per_day: 0.05, grow_days: 20, inherit_bond_share: 0.7, orphan_s: 3600, trust_gap_m: 8}`.
- **`data/animals/companion_abilities.json`** (new, shared by all companions): the bond steps above, by species.
- **`companions.json` save:** as #547 section 5. Nothing is baked, so a rebake never touches a companion.

## 5. Systems touched

1. **`server_wolves.gd`:**
   - pups at the den;
   - the "near pups" rush;
   - orphaning when the pack is gone.
2. **`server_animals.gd`:**
   - the orphan pup's hide and approach;
   - eating placed food. Dropped items exist; the animal side needs a "food on the ground" lookup.
3. **A new companion module, `server_companions.gd`:**
   - loads and saves the records, spawns near the owner, and runs follow, stay and come (the young-follow code);
   - warn (reads nearby creatures);
   - hunt and guard, which need animal-versus-animal attack. That doesn't exist today (GOBLINS.md lists it as not built), so hunt and guard come last.
4. **Client:** a name prompt, the companion marker, and the stay and come keys (rebinding, `docs/` controls list).
5. **Journal (#547):** taming is **Observed**, plus a companion page.

## 6. Recommendation on build order

Build the companion system on the **dog** first (species 34, models in batch 3). A stray dog follows a player who feeds it, which needs no pack, no den and no orphan rule. That proves `companions.json`, follow, stay and come, warn and inheritance. Wolf pups then reuse it and add only the den, orphan and wildness rules.

Wolf pups also need **wild packs switched on** (`natural: true`). **Dave said yes (8 Nov 2026)**, once the pack and pup work is built and checked on the PC. Until then, wolf pups are admin-spawn only.

## 7. How we know it works

- **Headless test (`test_companions.gd`):**
  - a fed orphan follows after N days;
  - a pup with a living pack can't be approached, and the pack rushes;
  - hunger to 0 makes it leave;
  - the record survives a save and load and passes to an heir with the bond share.
- **On the PC:** a picture of a pup following, the growl warning when a bear is near, and 0 shader errors.

## 8. Must not break

- Wild pack behaviour.
- `natural: false`.
- The fire and torch keep-off rule for wild wolves.
- Meat stealing by wild packs.
- Companions are never made by the wild spawner, and never counted against the per-player animal cap.

## 9. Depends on

- ~~Dave's reaction~~: given 8 Nov 2026 (section 10): this design, wild packs on, and orphans only.
- **MikeW:** a wolf pup model, either the wolf scaled with young proportions or a pup from the pack, plus clips.
- **Jason:** pup whines and a growl.

The dog companion is the first build, per section 6. Hunt and guard wait for animal-versus-animal fighting.

## 10. Decided by Dave (8 Nov 2026)

Dave answered the coordinator's questions with "I agree to all recommendations". For this design that means:

| # | question | decided |
|---|---|---|
| 3 | Can players raise a wolf pup as a companion? | **Yes, orphans only**: a pup whose pack is gone, fed over several game days (section 3) |
| 4 | Should wild wolf packs be on in the world? | **Yes**, once the pack and pup work is built and checked on the PC |
| 5 | Build the companion system on the dog first, then reuse it for pups? | **Yes**, the dog first (section 6) |
| 6 | Does an heir inherit a companion? | **Yes, at 70 % of the bond** |

Build order (coordinator, 8 Nov 2026): the dog companion (5, 6) comes after the bear ladder and the goblin work; wild packs and the orphan pup (4, 3) come last.
