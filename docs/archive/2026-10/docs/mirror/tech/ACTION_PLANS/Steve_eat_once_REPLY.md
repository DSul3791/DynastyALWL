# Tyler reply: Steve eat-once (9b626e5f), 25 Oct 07:16 UTC
GO as written. One reply; no more asks.
- RESTART (server_items, characters.json), no protocol bump. Numbers 150/150/3600/5 accepted.
- Branch today holds only the plan (base 3ba7b078, old). Rebase on build 799 after the inner-voice panel is rebased, and stack on that panel branch (hint_ prefix resolves as hint even before the classes file entry). Gate order: panel first, then eat-once.
- Save is additive: old characters.json without tried/grace_s load with defaults; test that.
- grace_s counts only online time; a character that logs out mid-hour keeps the rest.
- Admin "become a new player" clears tried and refills grace_s.
- Zero new warnings (baseline 233); commit .gd.uid for test_eat_once.gd; send exact head hash for David3 gate; QA card for Dave's fiddlehead check.
