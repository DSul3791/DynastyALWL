# Torches and Tree sap

Dave's design, 16 Nov 2026 (project thread "Restore torch recipes and add tree sap"): "it should be a simple torch(stick, twine, plantfiber), improved torch(stick, twine, plantfiber, tree sap). if tree sap doesn't exist add it to our items list. you get it whenever you cut down a softwood tree or process softwood logs into anything."

## What changed
- **Simple - Torch** (`torch`, item 12, recipe 7): 1 Stick, 1 Twine, 1 Plant fibre, by hand, 2 s. Its put-out twin `torch_doused` (542) reads the same. Before this it was 1 Stick, 1 Plant fibre, 1 Pitch (the Pitch group: resin, pine tar or animal fat), set on 9-10 Nov 2026 by an AI session applying the coordinator's rulings on a recipe audit (a document since deleted from `dev`, recoverable from Git history), merged inside PR #890, commit `5afa9ae2f` ("torch takes pitch"); earlier still it was 1 Stick, 2 Plant fibre. Twine was never in it before.
- **Improved - Torch** (`improved_torch`, item 1488, recipe 735): 1 Stick, 1 Twine, 1 Plant fibre, 1 Tree sap, by hand, 3 s. A torch in every way (tool class `torch`, off hand, put out by rain and water, lit again at a fire or with the hotkey), with its own put-out twin `improved_torch_doused` (1489) and its own placed pieces, `improved_standing_torch` (1490, state 448) and `improved_torch_sconce` (1491, state 449), so one set down and taken back is still Improved.
- **Tree sap**: the existing `resin` item (1115, conifer sap in amber lumps) is renamed Tree sap; no second item was added. `wood_species.json` `tree_sap` holds the amounts.
  - Every felled softwood tree (a species `wood_species.json` marks `class: softwood`: Scots pine, Spruce, Balsam fir) gives `felled` Tree sap: beside the trunk for a large tree, with its firewood for a small one (`server_items._felled_sap`).
  - A loose softwood log picked apart into kindling with a pickaxe also gives `per_softwood_log` (beside the kindling).
  - Every craft that uses up softwood logs (the `log_spruce` group: Spruce log, Scots pine log and the plain Log) gives the crafter `per_softwood_log` Tree sap per log (`server_items._craft_sap`): Planks at the sawmill or by saw, Wooden blocks, the longbow, the anvil parts. Hardwood logs give none.
  - A Tree sap need is also picked from a standing pine or spruce with a knife (`flora.json` yields `resin`, unchanged).
- The Pitch group (for the Fire arrow) keeps Tree sap, Pine tar and Animal fat.

## For Dave (assumed on his behalf, provisional; change in data/items only)
- TS-1: Tree sap is the old Resin item renamed, not a new item: Resin already was "sticky sap from conifers" and already came from felled pines, spruce and fir. Say if you want Resin kept as its own thing.
- TS-2: a felled softwood tree gives 2 Tree sap, large or small. The old chance roll per log (each log about 28%, 1 to 2 resin) is kept on top, so a big pine gives a little more.
- TS-3: 1 Tree sap per softwood log processed: by a craft, or picked apart into kindling with a pickaxe (`_chop_loose_log`; the sap lies with the kindling). Building with whole logs (Rustic walls, palisades) and burning logs do not count as processing.
- TS-4: one of each ingredient in both torches; Simple 2 s, Improved 3 s; both known from the start.
- TS-5: the Improved torch is tier 2, gives the same 12 m light as the Simple torch, and burns twice as long (60 min in hand, 60 min set in the ground or a wall, against 30). Value 10 copper (Simple 6), weight 0.45 kg (Simple 0.4).
- TS-6: the Improved torch and its placed pieces look exactly like the Simple ones for now (same model, icons copied from the Simple torch's); no new art.
- TS-7: Hob still sells only the Simple torch.
- TS-8: carrying an Improved torch counts as a lit torch for the night-walk goal, as the Simple one does. The "Light the night" camp goal (`camp_goals.json` torch_night) still asks for a crafted Simple - Torch, as its hint says.

## Not checked
Nobody has played it. The felled sap heap and the craft sap are covered by `src/worldgen/tools/test_tree_sap.gd` (run on a test lane, never in the cloud).
