extends Node

# The runway is a single shared resource - only one aircraft may be on it
# at a time, so two departures triggered close together queue instead of
# flying through each other.
#
# Usage from WorldAircraft:
#     await RunwayControl.acquire(self)   # blocks until the strip is clear
#     ...fly it...
#     RunwayControl.release()
#
# VTOL models never call this at all - they lift straight off the pad, so
# a congested runway is exactly the advantage a tiltrotor should have.

signal queue_changed

var _busy := false
var _queue: Array[Dictionary] = []  # {owner: Node, is_landing: bool, token: int}
var _next_token := 1


# Waits (as a coroutine) until this caller owns the runway. Landings take
# priority over departures: a plane already in the air can't hold, one
# sitting on its apron can.
func acquire(owner: Node, is_landing: bool = false) -> void:
	var entry := {"owner": owner, "is_landing": is_landing, "token": _next_token}
	_next_token += 1
	_insert(entry)

	while true:
		_prune()
		if not _busy and not _queue.is_empty() and _queue[0]["token"] == entry["token"]:
			break
		# The owner going away mid-wait (scene rebuild, plane freed) drops
		# it from the queue via _prune - bail rather than wait forever.
		if not is_instance_valid(owner):
			return
		await queue_changed

	_queue.pop_front()
	_busy = true


func release() -> void:
	if not _busy:
		return
	_busy = false
	queue_changed.emit()


func is_busy() -> bool:
	return _busy


func waiting_count() -> int:
	_prune()
	return _queue.size()


func _insert(entry: Dictionary) -> void:
	if not entry["is_landing"]:
		_queue.append(entry)
		queue_changed.emit()
		return
	# Ahead of every departure, but behind any landing already holding -
	# landings stay first-come among themselves.
	var idx := _queue.size()
	for i in range(_queue.size()):
		if not _queue[i]["is_landing"]:
			idx = i
			break
	_queue.insert(idx, entry)
	queue_changed.emit()


# An aircraft freed while queued would otherwise sit at the head of the
# queue forever and deadlock everything behind it.
func _prune() -> void:
	var before := _queue.size()
	_queue = _queue.filter(func(e: Dictionary) -> bool: return is_instance_valid(e["owner"]))
	if _queue.size() != before:
		queue_changed.emit()
