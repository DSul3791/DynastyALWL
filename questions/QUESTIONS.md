## collapse-test-3 | Please test the tunnel collapse after the backup. Look for: warnings that build up over 5 minutes, then the roof falls. Did it work?
Note: 1. Pull, close the game fully, start it, check the HUD says the new build number.
Note: 2. Go to solid ground (not a natural cave). Check Esc > Settings: Tunnel collapse is On and Cave-in time is 5 min.
Note: 3. Dig a tunnel about 2 m wide or wider. Stay near it.
Note: 4. Watch the 5 minutes: quiet at first, then creaks, then shaking with dust and the line "The earth groans.", then "The roof is giving way. Get out now!" every 5 seconds. The shaking part should last at least 90 seconds.
Note: 5. Stand OUTSIDE when the time runs out. The roof should fall, fill about 70% with rubble and leave the top open to dig out.
Note: 6. Optional: place a timber prop near the roof before the time runs out. The shaking should stop within 5 m of it.
Note: 7. Take a picture of the shaking and dust. Write in Notes what happened, yes or no.
[test]

## block-hand | Please test the chopping block in your hand. Look for: same model as the placed one, but smaller in hand.
Note: 1. Give yourself a chopping block (admin menu).
Note: 2. Hold it in first person: it should fit the hand and not be cut off at the screen edge.
Note: 3. Drop it, then place another next to it. Compare the three.
[test]

## hoe-spade-row | Please take a picture of the 4 hoes and 3 spade sizes in one row, at x 53301, z 68427.
Note: 1. Give yourself a wooden, stone, iron and steel hoe and the small, medium and large spade.
Note: 2. Drop all seven in one row on the ground at the spawn.
Note: 3. Take a picture from about 2 m away.
[picture]

## axe-bucket | Please take a picture of a stone axe and a bucket on the ground, at x 53301, z 68427.
Note: 1. Drop a stone axe and a bucket side by side.
Note: 2. The axe should look like a wedge, the bucket light wood with dark hoops.
[picture]

## hoe-hold | Please test the hoe: hold the left mouse button with a wooden hoe and walk forward on grass. Look for: a continuous line of flat tan path patches.
Note: 1. Hold the wooden hoe.
Note: 2. Hold the LEFT mouse button and walk forward on grass.
Note: 3. Then hold the RIGHT button on a rough strip to smooth it. It should get smoother, the hoe should wear only when ground moves, and "This ground is worked enough." shows when it refuses.
[test]

## spade-raise | Please test spade Raise mode. Look for: each click takes soil from your pack and the pack count drops.
Note: 1. Switch a spade to Raise mode (right click).
Note: 2. Click on the ground.
Note: 3. Small spade should use 1 piece per click, medium 4, large 8.
[test]

## collapse-switch | Please test the tunnel collapse switch. Look for: green On, red Off, no shaking while Off, cave-in time kept after rejoining.
Note: 1. Esc > Settings > Tunnel collapse: press it Off, then On.
Note: 2. Press Cave-in time through 2, 5, 10, 20 min.
Note: 3. Quit and rejoin; the time should still be what you set.
[test]

## collapse-natural | Please test a natural cave. Look for: no shaking and no collapse.
Note: 1. Walk into a natural cave you did not dig.
Note: 2. Stay 10 minutes (do something else nearby).
[test]

## collapse-prop | Please test a timber prop. Look for: the shaking stops within 5 m of the prop.
Note: 1. Dig a tunnel about 2 m wide and wait for the shaking to start (use cave-in time 2 min).
Note: 2. Place a timber prop 3 m from the roof.
Note: 3. Shaking should stop near it (7.5 m for a timber set).
[test]

## vsync | Please test VSync. Look for: On green, Adaptive amber, Off red, and the same after restart.
Note: 1. Esc > Settings > VSync: press it through all three.
Note: 2. Look for "(vsync X)" next to the fps in the top text.
Note: 3. Restart the game; the setting should be kept.
[test]

## ladder | Please test a ladder. Look for: it climbs, comes down, lets go backwards and steps you onto the top edge.
Note: 1. Place a ladder against a wall and face it.
Note: 2. Hold W to climb, then S to come down, Space to let go backwards.
Note: 3. Climb to the top and hold W: you step onto the edge.
[test]

## sound-fire | Please test Esc > Settings > Sound test: fire. Look for: each step is heard, from embers to the hiss when it is put out.
Note: 1. Open Esc > Settings > Sound test.
Note: 2. Press the fire sounds one by one.
[test]

## far-water-2 | Far rivers and lakes: should the flat distant picture of water follow your draw-distance setting, so it costs nothing on Low?
Note: Far water is the cheap flat picture of rivers and lakes beyond the normal draw range, so walking down a river you do not see the water vanish.
Note: Low: off. High: 32 m spacing. Ultra: reaches 3 tiles.
Note: Tyler recommends Yes because players with slow computers lose nothing, and strong computers get the long river views.
[check]

## river-mouth-dam | If a player dams a river where it meets the sea, should the river back up like a real dam until it goes over or around?
Note: A dam across the mouth raises the water behind it. If the dam does not reach all the way round, the water finds the low way around.
Note: Tyler recommends Yes because it is what the water simulation does by itself, so players can learn to read the land.
[check]

## loose-fill-slope | Should sand and loose soil refuse to be placed on ground steeper than they would slide on ("too steep, it would slide")?
Note: Sand about 34 degrees, soil about 40, gravel about 38. Stone and rock go anywhere. A hole always fills.
Note: Tyler recommends Yes because it feels like real dirt without running a sliding simulation (cheap, no lag). A real settling pass can come later.
[check]
