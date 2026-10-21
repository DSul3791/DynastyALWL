extends RefCounted

# The one interface between an NPC and whatever speaks for it (items/NPC_DESIGN.md section 2). StaticProvider answers from data
# trees and is always available; an AI provider will answer asynchronously later behind a router. Both return the same line shape:
#   {"text": String, "source": "static" or "ai", "voice_id": String, "choices": Array of String, "map": Array of next node ids
#    (same length as choices; "end" ends the talk), "node": String, "end": bool, "effects": Array}
# The server owns every fact and applies the effects itself; a provider never touches the game.

func available() -> bool:
	return true


# Start a talk with an NPC. `ctx` is built by the server: {"flags": Dictionary, "hour": float, "has_item": Callable(id, n) -> bool,
# "recent": Array (line hashes shown lately, which the provider may extend)}.
func open(_npc_id: String, _ctx: Dictionary) -> Dictionary:
	return {}


# Continue from a node when the player picks a choice (`choice` indexes the line's "choices").
func choose(_npc_id: String, _node: String, _choice: int, _map: Array, _ctx: Dictionary) -> Dictionary:
	return {}
