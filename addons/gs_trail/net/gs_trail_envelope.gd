class_name GSTrailEnvelope
extends RefCounted

## Carries trails over a gs-server envelope kind instead of a game's GSNetManager, so a server host adds trails to any game without touching its netcode. Duck-typed on GSServer and GSClientLink: this addon does not require gs-server.

## Up: {id}. Down: {actor, id}. Optional, so a peer without trails still plays.
const KIND := &"gs.trail"
## GSEnvelope.Lane.EVENT, copied so this file parses without gs-server.
const LANE_EVENT := 2


## Server half: [param server] answers KIND through [param relay]; the relay's answers go out as KIND. Call before clients connect, as the kind is advertised at signon.
## [param refresh_fn] (`func(peer, id)`, may await) runs before a request the relay would refuse, so a trail bought a moment ago can be fetched.
static func serve(server: Object, relay: GSTrailRelay, refresh_fn: Callable = Callable()) -> GSResult:
	if server == null or relay == null or not (&"envelope" in server):
		return GSResult.fail(GSError.CODE_INVALID, "trail envelope: no server or relay")
	server.envelope.register(KIND, func(peer_id: int, payload: Dictionary) -> void:
		var id := _id(payload)
		if refresh_fn.is_valid() and GSTrailMessage.valid_wire_id(id) and not relay.allows(peer_id, id):
			await refresh_fn.call(peer_id, id)
		var _res := relay.receive(peer_id, id))
	relay.send_fn = func(actor: int, id: String, to_peer: int) -> void:
		var payload := {"actor": actor, "id": id}
		var targets: Array = [to_peer] if to_peer > 0 else relay.peers()
		for peer: int in targets:
			server.send_kind(peer, KIND, payload, LANE_EVENT)
	return GSResult.success(relay)


## Client half: registers KIND on [param link]'s envelope (before it connects) and routes [param client] through it.
static func attach(link: Object, client: GSTrailClient) -> GSResult:
	if link == null or client == null or not (&"envelope" in link):
		return GSResult.fail(GSError.CODE_INVALID, "trail envelope: no link or client")
	link.envelope.register(KIND, func(_peer: int, payload: Dictionary) -> void:
		client.receive(int(payload.get("actor", 0)) if payload.get("actor", 0) is int or payload.get("actor", 0) is float else 0, _id(payload)))
	client.send_fn = func(id: String) -> bool:
		return is_instance_valid(link) and bool(link.send_kind(KIND, {"id": id}, LANE_EVENT))
	return GSResult.success(client)


static func _id(payload: Dictionary) -> String:
	var v: Variant = payload.get("id", "")
	return String(v) if v is String else "\u0001"
