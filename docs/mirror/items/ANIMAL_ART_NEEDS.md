# Animals: models, animations and sounds wanted from Art (Radar, 2026-10-21; Mandy owns art and sound)

Placeholders are drawn today by src/client/animal_view.gd (the deer shape recoloured). Species numbers on the wire: 1 rabbit, 2 deer, 3 wolf, 4 moose. Animation states come from the animal row state number.

## Moose (species 4, build 543), about 2.7 m long, 2.1 m at the shoulder, dark brown, bull has big flat antlers, cow none
States: 0 graze (head down, ear flicks), 1 walk/hop (slow walk, 1.6 m/s), 2 flee (gallop 10 m/s), 3 alert (head up, ears forward, still), 10 WARN (head lowered, ears flat, pawing and stamping, about 2.2 s; this is the telegraph that lets players dodge, make it unmistakable), 11 CHARGE (heavy gallop 11 m/s, head low), 12 RECOVER (standing, blowing, 5 s). Death: fall to the side.
Sounds: snort and soft grunts when alert, a loud bellow when warning, hoof thunder when charging.

## Wolf (species 3): model, animations (stalk crouch, circle, attack, play roll, play bounce), growl and howl clips (see sound/RECORDINGS_WANTED.md).

## Fox (species 5, build 544, built): trot, sneak, sniff at food, steal and sprint with meat in the mouth, yip), bird flock (species 6: floating on water, taking off together, flying in a V, honk and quack), later boar and bear.

## Bird flocks (species 6, build 547): ducks and geese on ponds and lakes
One wire record per flock; the client draws 6 to 13 birds spread over about 6 m from the record id. States: 0 floating (drift, dabble, preen), 3 alert (heads up, still), 15 TAKEOFF (the whole flock runs on the water, rises together, banks and flies off; flying V or loose line, wing beats). Model: one duck (mallard-like: green head, brown body) and one goose; the flock spreads them. Sounds: quacks and honks when alert, a burst of wing noise and alarm calls at takeoff. Next after birds: boar and bear (not requested yet).

## Horse (Dave 2026-10-21, for Mandy, not urgent)
Model (adult, foal), coat variants, walk, trot, gallop, graze, head-up alert, rear, buck, rest, foal nursing; sounds: whinny, snort, hoofbeats on grass, soil, stone. Later: saddle and harness meshes, a pulling pose.
