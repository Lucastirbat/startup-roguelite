extends Node

# Autoload: talks to the global leaderboard API on the game server.
# Fire-and-forget HTTPRequest nodes; callbacks always fire, even on error.

const API_URL := "https://reaktorx-runway.fly.dev/api/leaderboard"

# cb receives (ok: bool, entries: Array of {name, score, month, date} sorted
# by score desc). ok is false when the server is unreachable.
func fetch_top(cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if code == 200:
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Array:
				cb.call(true, parsed)
				return
		cb.call(false, []))
	if req.request(API_URL) != OK:
		req.queue_free()
		cb.call(false, [])

# cb receives true on success.
func submit(player_name: String, score: int, month: int, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		req.queue_free()
		cb.call(code == 200))
	var body := JSON.stringify({"name": player_name, "score": score, "month": month})
	var err := req.request(API_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		req.queue_free()
		cb.call(false)
