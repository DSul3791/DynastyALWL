## load-exertion-own-link | When the server is overloaded players tire faster. Should a player whose OWN connection is weak (but the server is fine) also tire faster? (my pick: no, only server load counts)
- No, only server overload makes actions harder (a player on bad wifi is not punished)
- Yes, a weak personal connection also makes actions harder for that player

## warning-cleanup-frozen | May Willy add warning-silencing annotations to the frozen terrain-generator files (no change to the baked result, checked by identical test-bake hashes)? (my pick: yes, gated)
- Yes, annotations only, and only if the test bake of 3 tiles is byte-identical before and after
- No, leave the frozen files alone until the next real bake
