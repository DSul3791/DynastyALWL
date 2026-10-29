# Tyler reply (once, 24 Oct 20:55 UTC): Steve go-spawn, nature-debug, sound-sliders - GO as one bundle
One answer for the class (BP-T52), all client-only RUNTIME, no protocol change:
- steve-go-spawn ac4d53d5: Esc > Admin > Go to spawn. Keep it admin-only; 10 s fall protection stays.
- steve-nature-debug 5b8e4d59: F3 lines for loudest Nature/Wind voice. Debug only.
- steve-sound-sliders e2e093d8: long sliders. Old step saves must migrate (said so in the plan: good). No separate water slider for now (no bus split); Dave can ask later.
- steve-wind-bus, steve-fall-quiet (inside Kathleen's water-soft a18971dc) and steve-settle-memory ride in the same build as already answered.
Bundle branch for David3: claude/tyler-790a (all of these merged, cloud local_check PASS on the same Linux engine, parse_scan 381/0). Merge that tested id as the next build on David3 PASS, ahead of the thatch work.
