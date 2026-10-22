## terrain-opt | How should we fix the ground so water works like real nature? (Sonny's review, tech/TERRAIN_REVIEW.md)
Your requirements: deep lakes in natural basins, streams that gather rain and snowmelt, rivers that carry water away to farmland and sea, flood-prone fertile land, streams good for waterwheels and fishing, and natural channel shape (deeper on outer bends, shallow inside, pools and riffles, never a uniform ditch). Today only 32% of river cells sit where the ground really drains, and a 2 m rise floods 6 times the wet area. The first bake waits for this choice. Nothing is built until you pick.
- B: Find rivers and lakes from the terrain itself. Meets all requirements, including natural channel shape. 1 to 2 weeks. Threaded bake about 8 to 10 minutes for 9 tiles. Makes the held spill-chute patch unnecessary (recommended)
- A: Quick fix, snap the drawn rivers onto the land's channels. About 3 days. Fails 4 of 9 and only adds the bend depth: no snowmelt, no natural basins or outlets, no flood plains, no data for waterwheels or fishing
- C: Rebuild the whole foundation. Meets all 9 but 4+ weeks and everything redone
- Not yet, I want to talk it through first
