# Foam and white water below falls and rapids

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Kathleen (water look); Sonny (the record's turbulence class and falls). **Asked by:** Kathleen, `docs/design/art_water.md` (#587) section 11: "foam drawn from the turbulence class and the drops the flow sees, not as a fixed texture". Section 7 also covers falls, plunge pools and spray. **Related:** [water.md](water.md), `upland-streams-numbers.md` (#612, waterfalls), [water-clarity-after-rain.md](water-clarity-after-rain.md).

There are two different white things on a river.
- **White water** is air bubbles mixed into fast water. It lasts seconds and stays where the turbulence is.
- **Foam** is a stable froth held up by natural surfactants. It drifts downstream, gathers in lines and eddies, and can last for hours.

The game needs both, drawn from different inputs.

## Lessons (read these first)

1. **White water comes from air entrainment and needs a drop or a jump.**
   - **Fast flow running into slow flow** forms a hydraulic jump. Its look follows the upstream Froude number Fr = v / √(g·d) (EngineerExcel, hydraulic jump):

     | Fr | Jump | Look | Energy lost |
     |---|---|---|---|
     | 1 to 1.7 | undular | a train of standing waves about four depths long | under 5% |
     | 1.7 to 2.5 | weak | a smooth rise with small rollers | 5 to 15% |
     | 2.5 to 4.5 | oscillating | unstable, sends waves downstream | 15 to 45% |
     | 4.5 to 9 | steady | a stable white roller | 45 to 70% |
     | over 9 | strong | rough and intermittent | 70 to 85% |

     **Our reading, judged:** standing waves with little white at Fr under 1.7, white crests from about 2, and a full white roller from about 4.5.
   - **A plunging jet** (a waterfall into its pool) drives bubbles down.
     - In a laboratory plunging jet, the water near impact was about 10 to 12% air, falling to 4 to 6% a little way downstream.
     - The bubbles were about 1 mm across and rose at about 0.2 m/s.
     - The bubbly flow ran 2.5 to 5 water depths downstream before most bubbles surfaced (Chanson et al. 2002, plunging breakers).

     **Our reading:** the white patch below a fall reaches a few pool depths downstream, then goes clear quickly. Art's section 7 already says the stream "settles into clear water a few metres on".
2. **Foam needs surfactants. In nature they come from decaying plants.**
   - Fatty acids from plant lipids, lignin from wood and bits of protein, released as plants and animals decay (Tasmania EPA, foam and foam lines; Telford and Wrekin Council).
   - Only about 1% of foam is the foaming agent; the rest is air and water (Telford).
   - **Most foam:**
     - in tannin-rich and peat-brown rivers (bog water is high in dissolved organic carbon);
     - in autumn, at leaf fall;
     - after rain and high flows, which wash organic matter in;
     - on windy days;
     - below turbulent water such as weirs (Telford).

     Clear, nutrient-poor rivers can foam too in the right conditions.
3. **Foam gathers where flows meet.**
   - It collects in foam lines where flows of different speed meet: at confluences, in eddies and below waterfalls (Tasmania EPA).
   - It also gathers against obstructions and shorelines, and where waves break on rocky lake shores (Wikipedia, Foam line).
   - **Our reading, judged:** the foam line traces the seam between the fast tongue and the slow edge water, which anglers read as the line where food drifts.
4. **Natural foam ages from white to brown and lasts a while.** It often starts white and turns light tan or brown as it picks up organic matter. It "can persist for some time gradually diminishing in size" (Telford; Tasmania EPA). Detergent foam stays bright white and stays near its source.
5. **Winter foam can freeze.** Foam can freeze at night into "ice pancake" discs, up to about 10 cm thick and 0.3 to 3 m across. This is reported, and its cause is a theory (Wikipedia, Foam line).

## A model for the game (judged, for Kathleen and Sonny)

**White water (aeration) is per pixel, from the flow.**
- Strength rises with the local Froude number:
  - none below 1;
  - white crests from about 2;
  - full white from about 4.5.
- At a fall or drop, add a white patch over the plunge pool. Its length is 3 pool depths (from the 2.5 to 5 above) and its width is the fall's width plus spray.
- Bubbles surface and vanish within about 2 to 5 seconds of leaving the turbulence.
- Rain does not make white water. More flow makes more of it, because v rises.

**Foam (froth) drifts and builds up.**
- **Sources:**
  - every fall's plunge pool;
  - every rapid or chute with Fr over about 2;
  - weirs;
  - wave-beaten lake shores on windy days.
- **How much a source makes:** (turbulence) × (organic richness) × (season):
  - organic richness is high for peat or forest-fed reaches and low for bare rock or glacier water;
  - season is highest in autumn, and also after rain.
- **Movement:** the foam travels with the surface flow and slows into the slack water.
- **Where it gathers:** in lines along the seam between the fast tongue and the slow edge, in eddies behind rocks and below bends, and against the shore on the downwind side.
- **Lifetime:** a fleck shrinks with a half-life of about 10 to 30 minutes, longer in calm eddies (judged; the sources say only "some time").
- **Colour:** white when fresh, light tan when old, beige-brown on peat rivers. Never bright white far from a fall.
- **Winter:** foam in still eddies can freeze into pale discs when the pond ice rule (#616) gives ice.

**Never-see checks:**
- foam on a still pond with no inflow, and no wind or waves;
- white water on a calm, slow reach;
- a fixed foam texture that does not move with the current;
- clean white foam a kilometre below a fall on a peat river.

## How ours works today

Not checked in code for this page. The record design gives each reach a turbulence class and lists falls with their drops (`docs/water/watershed_rebuild_design.md`). The water shader draws surf foam at the sea shore (`water_material.gd`, the sea's shore foam).

## Sources

- EngineerExcel, Hydraulic jump (classification by Froude number): https://engineerexcel.com/hydraulic-jump/
- Chanson, H. et al. (2002), air entrainment in plunging breakers and a pseudo-plunging jet: https://data-ww3.ifremer.fr/BIB/Chanson_etal_CE2002.pdf
- Tasmania EPA, Foam and foam lines: https://epa.tas.gov.au/environment/water/water-topics/foam-and-foam-lines
- Telford and Wrekin Council, Foam in rivers and still waters: https://telford.gov.uk/download/downloads/id/28515/foam_in_rivers_and_still_waters.pdf
- Wikipedia, Foam line: https://en.wikipedia.org/wiki/Foam_line
