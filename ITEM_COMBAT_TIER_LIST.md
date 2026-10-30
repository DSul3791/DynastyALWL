# Weapon, shield and armour tier list (proposal, names and recipes only; Sal, 2026-10-30)

Spec only: nothing is in the data files yet. If approved, each row becomes a `future` item with a recipe of 3 ingredients or fewer. Ladder follows ITEM_TIER_BALANCE.md (wood/hide, stone, copper/bronze, iron, steel). Names are the common ones across Valheim, Ark, Conan, Vintage Story and Dragonwilds (from the comparison in ITEM_GROUPS_AND_NAMES.md; confidence is as flagged there).

| Tier | Sword / blade | Mace / club | Shield | Armour (body / head) | Station |
|---|---|---|---|---|---|
| 1 Wood and hide | (Wooden club 300 exists) | Wooden club | Wicker shield (stick x3, plant fibre) | Hide tunic 305 exists / none | hand |
| 2 Stone | Stone knife 11, Obsidian knife 296 exist | Stone mace (stone, stick, cord) | Plank shield (plank x3, hide) | Hide tunic + leather cap (leather x2) | hand / bench |
| 3 Copper and bronze | Bronze sword (bronze ingot x2, stick) | Bronze mace (bronze ingot x2, stick) | Bronze-rimmed shield (plank x2, bronze ingot) | Leather jerkin (leather x3), bronze helm (bronze ingot x3) | bench + forge 2 |
| 4 Iron | Iron sword (iron ingot x2, leather) | Iron mace (iron ingot x2, stick) | Iron-banded shield (plank x2, iron ingot x2) | Gambeson (cloth/fibre x3), iron helm, mail shirt (rivets x2, iron ingot x2) | bench + forge 2 |
| 5 Steel | Steel sword (steel ingot x2, heavy leather) | Steel mace | Steel kite shield (plank, steel ingot x2) | Plate cuirass, steel helm (special: 4 ingredients) | bench + forge 3 |

Notes
- Fun and simple: each weapon type has one clear job (sword: fast, mace: breaks armour, shield: block). Slings and javelins stay as thrown/ranged items (Javelin 295 exists).
- Depends on the ore and smelting code (see ITEM_CODE_HANDOFF.md). Bronze needs copper and tin; the bench rule and forge levels are unchanged.
- Open for Dave: does the shield go in the off-hand slot (the validator today allows only torch and shield there)? Is plate armour too late for the first island?
