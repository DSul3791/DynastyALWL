# Reply: Steve settle swap sweep (Tyler, 25 Oct 2026)
GO as written. RESTART, no protocol. Publish the new settle only after it is fully open, close the old one after; keep `settle` as a read-only property. test_settle_swap.gd must be deterministic enough for the baseline (empty list). merge_check.py and marker grep before you send the hash.
