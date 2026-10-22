extends RefCounted

# The identity swap point (Steve's guardrail, 2026-10-21). The server asks a provider who a connecting peer is and only ever
# handles the account id it returns: "local:<player key>" today. A real login (accounts, tokens) replaces LocalIdentity with
# another provider that returns its own ids; the per-player stores keep using store_key(account_id), which for local ids is the
# raw key, so every existing save file stays valid.
#
# authenticate(peer, credentials) -> account id, or "" to refuse the connection.
# store_key(account_id) -> the key the per-player stores use ("" when the id is not one of this provider's).
# is_local() -> true for the key-on-your-own-disk provider. The admin check must be on for any public server.

const PREFIX := "local:"


func authenticate(_peer: int, credentials: String) -> String:
	return PREFIX + credentials if credentials != "" else ""


func store_key(account_id: String) -> String:
	return account_id.substr(PREFIX.length()) if account_id.begins_with(PREFIX) else ""


func is_local() -> bool:
	return true
