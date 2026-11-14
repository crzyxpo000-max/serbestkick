class_name MatchEvent
extends RefCounted
## Hızlı akan maçtaki bir olay.

enum Kind { COMMENT, GOAL_US, GOAL_THEM, FREE_KICK }

var minute := 0
var kind := Kind.COMMENT
var text := ""
var free_kick: FreeKick


static func make(p_minute: int, p_kind: Kind, p_text: String, p_free_kick: FreeKick = null) -> MatchEvent:
	var event := MatchEvent.new()
	event.minute = p_minute
	event.kind = p_kind
	event.text = p_text
	event.free_kick = p_free_kick
	return event
