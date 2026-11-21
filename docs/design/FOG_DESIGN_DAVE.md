# Fog: Dave's instruction (Game Director), 14 Nov 2026 16:06Z

Status: APPROVED DESIGN (Dave's own words, verbatim below the line; thread "Make fog look and behave naturally"). Supersedes the look rules in docs/design/valley_fog.md where they differ. Technical implementation is left to the team: docs/design/FOG_PLAN.md.

---

here is my instruction on Fog

Implement natural-looking fog in Dynasty: A Life Well Lived using the following description. Choose the technical implementation yourself.
What fog should look like
Fog occupies the world around the player. Nearby objects remain readable, while visibility gradually deteriorates with distance. Objects lose contrast, colour, and detail before becoming faint silhouettes and finally disappearing.
For a dense-fog starting point:

* Within roughly 10 metres, the ground, tools, characters, and nearby objects remain easy to see.
* Around 10–20 metres, fog becomes increasingly noticeable.
* Around 20–40 metres, objects become indistinct shapes and silhouettes.
* Beyond that, the landscape is mostly obscured.

These are adjustable visual targets, not fixed distances for every fog event. Light mist should allow much longer views; exceptionally thick fog can restrict nearby visibility. Avoid a perfectly clear bubble around the player or a visible wall where fog suddenly begins.
Fog surrounds the player
Fog must affect views in every direction, including upward and downward. When the player is surrounded by deep, thick fog, looking up should reveal a fog-obscured sky rather than a clear blue sky. Stars, distant clouds, and celestial objects should also become obscured. The sun or moon might appear as a soft, faint disc.
Shallow ground fog is different: the sky can remain visible when there is little fog overhead. A player climbing above a valley’s fog should be able to see clear air above it and the fog filling the valley below.
When fog should happen
Fog should develop from suitable combinations of moisture, temperature, terrain, and weather. Cold weather alone is not enough.

* Overnight and early morning: Moist air cooling overnight can produce fog, especially during clear nights with light winds. Fog can begin before dawn, deepen toward morning, and gradually clear as the ground and air warm.
* After rain: Rain leaves wet ground and vegetation and supplies moisture. If conditions then cool toward saturation, particularly overnight with light winds, fog becomes more likely. Do not automatically trigger several hours of fog after every shower. A warm, dry, windy afternoon may clear without fog.
* Near rivers, lakes, and wetlands: These areas should be more prone to local mist when moisture and temperature favour it. Cold air over warmer water can produce low drifting wisps that resemble steam. This need not happen every morning or remain confined to morning.
* Valleys and low ground: Fog can collect and deepen in sheltered low areas while nearby slopes and hilltops remain clear. River valleys can develop broader fog than the narrow wisps immediately over the water.
* Coasts and cold water: Moist air moving across a colder surface can develop fog banks that drift inland. This fog can occur during the day and persist when the conditions continue.
* During rain: Fog may also develop during suitable rainy conditions; it does not always have to wait for rain to stop.

Use these as natural tendencies, allowing variation rather than making every location follow a predictable daily schedule.
How fog develops and clears
Fog should form gradually, starting as thin patches or shallow mist where appropriate. It can deepen, spread, merge into larger banks, and later break apart.
Its duration should depend on conditions. Some morning fog may clear over a few in-game hours as warmth and mixing increase. Deep valley fog or coastal fog may persist much longer. Sunrise should not instantly remove it, and continued cool, damp conditions can keep it present.
Light winds can move fog slowly. Stronger winds often disperse shallow ground fog, while winds carrying a fog bank can bring more fog into an area. Avoid one universal rule that wind always removes fog.
Movement and boundaries
Use broad, subtle changes in density and slow drifting patches. Fog should feel like suspended moisture, without constant boiling smoke, obvious repeating patterns, or frantic movement.
Entering or leaving a fog bank should feel gradual. Fog belongs to locations in the world; it should not visibly follow the player or turn on and off when they cross an invisible boundary.
Light and colour
Daytime fog should receive soft environmental light and reduce distant contrast. Its colour should respond naturally to daylight, sunrise, sunset, and nearby illumination.
Night fog should be dark unless lit. It should not make an unlit landscape glow white. Torches, lamps, and fires can create softened halos or visible shafts of light, while objects behind them remain obscured.
Shelter and gameplay
Enclosed buildings and caves should not automatically contain the same fog as the outdoors. Looking through an open doorway should still show the fog outside. Open shelters and cave entrances can have gradual transitions where appropriate.
Fog should obscure distant terrain, water, buildings, vegetation, animals, and characters consistently. If it restricts player visibility, it should also reduce creatures’ visually based detection appropriately, while allowing hearing and other senses to continue working.
What a successful result should feel like
The player can comfortably handle nearby tasks while sensing the world disappearing into the fog. A river can carry low morning mist, a valley can fill beneath clear hills, and a thick fog bank can surround the player and hide the sky. Each should feel like a believable weather condition.
Check the result in daylight and darkness, with and without a torch, looking in every direction, entering and leaving fog, climbing above it, and viewing it through a doorway.
