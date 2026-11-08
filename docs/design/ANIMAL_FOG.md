# Animals in fog, mist and dusk (MikeW, 8 Nov 2026)

From Jamie's fog page (#716, `docs/knowledge`), her sound-outdoors page (lesson 7) and sounds-of-weather page (#683), with
Kathleen's valley fog (#672) and sea fog (#608). Client looks behind `fog_looks` (off). Seasons are the game calendar's (the island is
at 57 degrees south): sea fog comes in local spring to early summer, valley fog in local autumn into early winter.

## What fog does (knowledge, Jamie #716)
- **Visibility V:** mist 1 to 2 km, fog 180 to 1,000 m, thick fog 50 to 180, dense under 50. One sees movement at V, recognises a
  person or animal at half V, sees detail at a quarter V.
- **Sight for an animal:** the smaller of its clear range and half V. Hearing is unchanged, a little better in the calm that comes
  with fog. Trail scent about 1.25 times (judged); wind-borne scent less.
- **Behaviour (judged):** stock bunch, their spread halved; deer feed one to two hours later into the morning, near the wood edge;
  songbirds sit low and quiet; gulls and waders sit on the water or the shore; raptors and ravens perch; bats fly as usual with fewer
  passes; wolves close in unseen to half V; the spook range shrinks to hearing and smell.
- **Eye shine** shows to about a third of V, with the torch held low.
- **More from the fog page (#716):** sea fog lifts at wind 0.32 on the shared mapping, not 0.5 (Kathleen's sea fog rule, #608, not the
  animal looks). Airborne scent needs a light wind: in dead-calm fog it carries poorly, though trail scent (on the ground) is still
  about 1.25 times. Birds avoid flying into fog.
- **Sound:** fog does not make sound carry; the droplets take the high notes, low sounds carry best; it feels quiet because it
  comes with calm air (sound-outdoors lesson 7). Kathleen's outdoor rules (#662) already cut the high end in fog for every sound.

## In the game (flag `fog_looks`)
| Look | How |
|---|---|
| Fading to a silhouette | nothing new: the scene's fog (Kathleen's weather look) already fades every animal with distance like everything else, and the eye-shine dots with it |
| Eye shine sooner and shorter | below 180 m visibility the shine starts at dusk (night 0.05 instead of 0.15), and it reads to a third of V at most (`_eye_shine_night`) |
| Voices | no change in the voice hook: the fog's high cut is Kathleen's sound-stage rule for all sounds, and low calls (a bellow, a howl) carry as the knowledge says; a separate cut here would double it |
| Steam into the mist | in mist over 0.3 the breath puff is half as opaque and lingers 1.6 times as long, merging into it |
| Herds closer | below 1,000 m visibility the on-screen herd spacing is halved (`_herd_space`) |
| Birds grounded | server: the states it sends (see the requests) |

## The fog values the client reads (for Kathleen, #608 and #672)
`fog_now` in terrain_client returns a Dictionary. Today it builds it from what exists: `density` (the scene Environment's
`fog_density`, which the weather look sets), `mist` and `mist_top_m` (the shared weather state). The client turns density into a
visibility as 3 / density (contrast down to 5 percent). **Asked of Kathleen:** expose `visibility_m` (metres, the V above, at the
camera) from the weather look, so the animal looks and her sound and sky code use one number; with it, the density guess is not used.

## Requests to Steve (server, from Jamie's judged behaviour)
1. An animal's sight in fog: the smaller of its clear range and half V (the senses' sight distance), with hearing unchanged.
   Airborne scent: weaker in calm fog (wind under a light breeze), trail scent about 1.25 times (#716).
2. Wolves close in unseen to half V; the spook range of prey falls to their hearing and smell ranges.
3. In fog, songbirds, raptors and ravens perch (state 0 at their perch), gulls and waders sit; deer feed later into the morning near
   the wood edge. Birds do not take off into fog (no state 15 into a fog bank); the client needs nothing for it.
The server needs the same V at the animal; Kathleen's fog rule is in the shared weather, so `visibility_m` from Weather (not only
the client look) would serve both.

## Check
Run sheet m52 (deer herd and a wolf at dusk in 120 m fog with a torch: the shine shows though it is only dusk, the herd stands
closer, the shapes fade with distance) and DINO_SHOTS.md.
