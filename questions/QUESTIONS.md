
## bracing-grace | How long is the grace window after digging a soil tunnel before the earth starts to shake? (my pick: 30 real minutes, shorter for wider spans)
- About 10 real minutes
- About 30 real minutes (shorter for wider spans, longer for rock)
- About 60 real minutes

## collapse-lethal | Can a collapse kill a player who ignores the warnings? (my pick: heavy damage, buried, can be dug out)
- Heavy damage and buried; others can dig you out; death only if already hurt
- Always lethal inside the collapse
- Never lethal, only buries you for a while

## load-exertion-own-link | When the server is overloaded players tire faster. Should a player whose OWN connection is weak (but the server is fine) also tire faster? (my pick: no, only server load counts)
- No, only server overload makes actions harder (a player on bad wifi is not punished)
- Yes, a weak personal connection also makes actions harder for that player

## warning-cleanup-frozen | May Willy add warning-silencing annotations to the frozen terrain-generator files (no change to the baked result, checked by identical test-bake hashes)? (my pick: yes, gated)
- Yes, annotations only, and only if the test bake of 3 tiles is byte-identical before and after
- No, leave the frozen files alone until the next real bake
