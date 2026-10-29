# Wolf design card

## DECIDED by Dave (2026-10-21), built in build 510
1. Wolves stalk and leave a lone healthy player (a). 2. They CAN attack: they maim first (crippling injury, health stops at 25), back off and leave the player for about 5 real minutes; if the player is still around or no help came when they return, they kill. A deer or other prey near the pack draws it off. 3. Density: 1 pack per 4 sq km (2 km cells), tune later; natural packs are OFF in the data until Dave wants them (admin spawn works).
More from Dave: near a fire they stay just outside the firelight and circle, visible at its edge; with a torch they keep coming but only through shadow and never enter the torch light; they dislike fire. They growl and howl to summon other packs (howl pulls up to 2 prowling packs within 1.5 km). The closer the player is to the den the braver they get (longer notice, attack healthier players, ignore a spear). A calm unaware pack by day rolls in the grass and plays like dogs (states 8, 9); a quiet downwind watcher can see it.
Numbers live in data/animals/animals.json "wolves" and species "wolf". Not built yet: the limp for a maimed player (health only), growl/howl sound clips (events are logged in wolves.events for Mandy), true dens (den = the pack's spawn spot), day/night for play (always on unless a day callable is wired).


Nothing is built. Wolves are the first animal that can hurt a player, so this is your call. Numbers are for the same rules the rabbit and deer use (server-owned records, no physics, staggered ticks).

## Recommendation
Wolves are rare, live only in forest and hill country away from the starter town, hunt deer first, and attack a player only when the player is alone, wounded, carrying fresh meat or has cornered them. A fire, a group of two or more, or a raised spear sends them away. They are a danger you can read and avoid, not a spawn that ends a session.

## Numbers

| | Proposed |
|---|---|
| Pack size | 3 to 5; one leader (the first to notice) |
| Density | 1 pack per 4 square km of forest or hill; never within 400 m of the spawn or a placed campfire; none in the starter tile |
| Health | 30 each (deer 20, spear 8 per hit = four hits, three with a good skill) |
| Speed | walk 2.0, trot 5.0, sprint 10.5 m/s for 5 s then 7 (player run 6, jog 3.2: you cannot outrun them, you can reach a fire or a tree line) |
| Senses | alert 60 m, notice 35 m; smells you from 1.5x farther downwind, half upwind; crouching 0.6; hills block sight (same senses block as deer) |
| Behaviour | prowl as a pack, shadow a lone player at 25 m for 10 to 20 s ("stalk"), then circle and rush; the pack backs off if one is wounded (flee at 40 percent health) |
| Attack | bite 8 health, one bite per second per wolf, 3 m reach; a pack of 4 on a lone player is about 30 health a second at worst, so a lone fight is lost in 4 s |
| Armour | clothing warmth does not help; a later leather armour value can cut bites by up to 40 percent |
| Flee or fight | fight when: player alone and (health below 60 percent, carrying raw meat or a carcass, or out of a fire's light at night). Flee when: a fire within 8 m, two or more players within 10 m, a wolf is killed, or the player hits one. Otherwise they only stalk and leave |
| Fire | a campfire or forge fire holds them at 10 m (they circle, do not rush) |
| Loot | Wolf pelt x1 (clothing material, later), Raw meat x2 (spoils like venison), Fang x1 (craft material). One carcass per wolf, same carcass rules as deer |
| Respawn | a killed pack is gone for 2 game days, then a new pack may form at least 1 km away |
| Hunting them | a pit trap or spear from a fire line is the way; a single spear throw rarely kills |

## Tick cost (server, 20 players)
Measured now: 107 rabbits and deer in a 20-player stress run take 0.58 ms average, 1.2 ms p99 per tick (budget 2 ms for animals and NPCs). Wolves are rarer and need heavier thinking per animal (pack, stalk, line of sight), so I plan:
- at most 3 packs awake near any player, 15 wolves in total on the whole server,
- the same quarter-per-tick stagger, 10 Hz only within 60 m of a player, 3 Hz within 120 m, frozen beyond 200 m,
- a shared pack brain (one decision per pack per tick, wolves only follow slots), so 15 wolves cost about the same as 5 deer.
Expected extra: 0.15 ms average, 0.4 ms worst, so animals stay under 1.6 ms p99. I will measure with the stress test before it goes in.

## Wire cost at Low
Wolves reuse the animals rows (species 3, states stalk and attack as new state numbers): no new RPC, about 24 bytes per wolf near a player, 5 wolves = 120 bytes at 4 Hz = 0.5 KB/s. Damage to the player reuses the fall damage and Health path. Needs a protocol bump for the new states only.

## Questions for Dave
1. Do wolves attack a lone healthy player in daylight (my answer: no, they stalk and leave) or always when you are alone?
2. Can a pack kill a player outright (my answer: yes, but only a lone, wounded or meat-carrying one, with a long warning)?
3. Rare as proposed (1 pack per 4 square km), or even rarer?

## Meat and hunger (Dave 2026-10-21, build 536)
Wolves have a hunger level (0 just fed, 1 starving; rises over an hour, a kill or stolen meat resets it, new packs start at 0.4). A pack goes for a lone player who carries RAW meat as before; when hungry (0.6 and up) any meat counts, raw or roast; a fed pack ignores roast meat; a starving pack (0.9) will rush any lone player. Instead of crippling a meat carrier they keep biting and after 3 bites tear ALL the meat out of the pack and run off with it (the pack forgets the player for 15 minutes); dropping the meat ends the attack, the pack lets go. A fire or torch light always wins: nothing in these rules lets a wolf into light, and no meat is stolen inside light. Numbers: data/animals/animals.json wolves (hunger_*, hungry_at, starving_at, steal_bites). Test: test_wolves.gd block 11.
