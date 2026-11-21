class_name GSTrailWorkbench
extends RefCounted

## The trail form's server side: list, upload and delete a server's trails for owners and admins holding the `trail` flag. Built on gs-workbench's extension hooks ([method GSWorkbenchHttp.mount_extension], [method GSWorkbenchApi.add_flag]); gs-workbench knows nothing of trails. Everything is validated by [GSTrailStore]; the result is saved to the store directory, which is the pack source.

const CHANNEL := "workbench.trails"
const PREFIX := "/api/trails"
const FLAG := "trail"
const OP_LIST := "trail_list"
const OP_UPLOAD := "trail_upload"
const OP_DELETE := "trail_delete"

var api: GSWorkbenchApi
var store: GSTrailStore
## Called with no arguments after a change is saved, e.g. to rebuild the pack or tell connected players.
var changed: Callable = Callable()


func _init(p_api: GSWorkbenchApi, p_store: GSTrailStore) -> void:
	api = p_api
	api.add_flag(FLAG)
	store = p_store


## Adds GET /api/trails, POST /api/trails (the upload) and DELETE /api/trails/<id> behind the workbench's bearer token and lockout, ; the admin token holds the `trail` flag (added on construction).
func mount(http: GSWorkbenchHttp) -> void:
	http.mount_extension(PREFIX, _route, FLAG, PackedStringArray(["GET", "POST", "DELETE"]))


func _route(actor: Variant, req: GSHttpRequest) -> GSResult:
	var op := {}
	match req.method:
		"GET":
			op = {"op": OP_LIST}
		"DELETE":
			op = {"op": OP_DELETE, "id": req.rest.strip_edges().trim_prefix("/")}
		"POST":
			var parsed := req.json_body()
			if not parsed.ok or not (parsed.value is Dictionary):
				return GSResult.fail(GSError.CODE_INVALID, "body must be a JSON object")
			op = (parsed.value as Dictionary).duplicate()
			op["op"] = OP_UPLOAD
	return handle(actor, op)


## [param req]: `{op: "trail_upload", meta: {id, title, width, lifetime, color, blend, access, groups, price, licence, author, url}, image: <base64>, file: "x.png"}`, `{op: "trail_delete", id}` or `{op: "trail_list"}`. Value on success is JSON-able.
func handle(actor: Variant, req: Dictionary) -> GSResult:
	if not api.permits(actor, FLAG):
		GSLog.warn(CHANNEL, "trail request refused", {"op": str(req.get("op", ""))})
		return GSResult.fail(GSError.CODE_FORBIDDEN, "trails need the '%s' permission" % FLAG)
	match str(req.get("op", "")):
		OP_LIST:
			return GSResult.success(_list())
		OP_UPLOAD:
			return _upload(req)
		OP_DELETE:
			return _delete(str(req.get("id", "")))
	return GSResult.fail(GSError.CODE_INVALID, "unknown trail op")


func _list() -> Dictionary:
	var out: Array = []
	var registry: Object = store.get("registry")
	for id: String in registry.call("ids"):
		out.append((registry.call("get_def", id) as Object).call("to_dict"))
	return {"trails": out}


func _upload(req: Dictionary) -> GSResult:
	var meta: Variant = req.get("meta")
	var b64: Variant = req.get("image")
	if not (meta is Dictionary) or not (b64 is String) or (b64 as String).is_empty():
		return GSResult.fail(GSError.CODE_INVALID, "an upload needs meta (object) and image (base64)")
	var limit := int(store.get("registry").get("config").get("max_upload_bytes"))
	if limit > 0 and (b64 as String).length() > limit * 4 / 3 + 16:
		return GSResult.fail(GSError.CODE_QUOTA, "image is larger than %d bytes" % limit)
	var bytes := Marshalls.base64_to_raw(b64)
	var made: GSResult = store.call("submit", meta, bytes, str(req.get("file", "")))
	if not made.ok:
		return made
	return _persist({"id": str((meta as Dictionary).get("id", ""))})


func _delete(id: String) -> GSResult:
	if not bool((store.get("registry") as Object).call("remove", id)):
		return GSResult.fail(GSError.CODE_INVALID, "no such trail", id)
	return _persist({"id": id, "deleted": true})


func _persist(reply: Dictionary) -> GSResult:
	var saved: GSResult = store.call("save")
	if not saved.ok:
		return saved
	if changed.is_valid():
		changed.call()
	return GSResult.success(reply)
