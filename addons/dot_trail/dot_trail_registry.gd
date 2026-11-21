class_name GSTrailRegistry
extends RefCounted

## The set of trails a server offers, loaded from the pack's trails.json. Registered with GSRegistry, never an autoload.

const CHANNEL := "trail"
const SERVICE := &"trail_registry"
const INDEX_FILE := "trails.json"

var config: GSTrailConfig = GSTrailConfig.new()
var _defs: Dictionary = {}
## image file name -> validated bytes.
var _images: Dictionary = {}


static func current() -> GSTrailRegistry:
	return GSRegistry.get_service(SERVICE) as GSTrailRegistry


func install() -> void:
	GSRegistry.register(SERVICE, self)


func count() -> int:
	return _defs.size()


func ids() -> PackedStringArray:
	var out := PackedStringArray(_defs.keys())
	out.sort()
	return out


func get_def(id: String) -> GSTrailDef:
	return _defs.get(id) as GSTrailDef


## Adds a def and its image bytes. The image goes through GSTrailUpload.validate, so a pack cannot carry anything else.
func add(def: GSTrailDef, image_bytes: PackedByteArray) -> GSResult:
	if _defs.has(def.id):
		return GSResult.fail(GSError.CODE_CONFLICT, "trail id already exists", def.id)
	if config.max_trails > 0 and _defs.size() >= config.max_trails:
		return GSResult.fail(GSError.CODE_QUOTA, "trail limit reached (%d)" % config.max_trails, def.id)
	var ok := GSTrailUpload.validate(image_bytes, def.image, config.limits())
	if not ok.ok:
		GSLog.warn(CHANNEL, "rejected trail image", {"id": def.id, "code": ok.code()})
		return ok.wrap("trail " + def.id)
	_defs[def.id] = def
	_images[def.image] = image_bytes
	GSLog.debug(CHANNEL, "trail added", {"id": def.id})
	return GSResult.success(def)


func remove(id: String) -> bool:
	var def := get_def(id)
	if def == null:
		return false
	_defs.erase(id)
	var shared := false
	for other: GSTrailDef in _defs.values():
		shared = shared or other.image == def.image
	if not shared:
		_images.erase(def.image)
	return true


## Parses trails.json text and takes the images from [param files] (file name -> bytes). All or nothing.
func load_index(json_text: String, files: Dictionary) -> GSResult:
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(json_text) == OK else null
	if not (parsed is Dictionary) or not (parsed.get("trails") is Array):
		return GSResult.fail(GSError.CODE_PARSE, "trails.json must be an object with a trails array")
	var staged := GSTrailRegistry.new()
	staged.config = config
	staged._defs = _defs.duplicate()
	staged._images = _images.duplicate()
	for entry: Variant in parsed["trails"]:
		if not (entry is Dictionary):
			return GSResult.fail(GSError.CODE_PARSE, "trail entry is not an object")
		var made := GSTrailDef.from_dict(entry, config.limits())
		if not made.ok:
			return made
		var def: GSTrailDef = made.value
		if not files.has(def.image):
			return GSResult.fail(GSError.CODE_INVALID, "index names a missing image " + def.image, def.id)
		var added := staged.add(def, files[def.image])
		if not added.ok:
			return added
	_defs = staged._defs
	_images = staged._images
	return GSResult.success(_defs.size())


func to_index() -> String:
	var list: Array = []
	for id in ids():
		list.append(get_def(id).to_dict())
	return JSON.stringify({"trails": list}, "\t")


## Files a pack for these trails must carry: trails.json plus each image.
func pack_files() -> Dictionary:
	var out := {INDEX_FILE: to_index().to_utf8_buffer()}
	out.merge(_images)
	return out


func image_bytes(id: String) -> PackedByteArray:
	var def := get_def(id)
	return PackedByteArray() if def == null else _images.get(def.image, PackedByteArray())


## Builds a texture from the stored bytes; null when the id is unknown. Not called headless.
func texture_for(id: String) -> Texture2D:
	var def := get_def(id)
	if def == null:
		return null
	var img := Image.new()
	var bytes := image_bytes(id)
	var err := img.load_png_from_buffer(bytes) if def.image.get_extension().to_lower() == "png" else img.load_webp_from_buffer(bytes)
	return null if err != OK else ImageTexture.create_from_image(img)


## The access rule. [param entitlements] are ids the backend says the player owns (purchases).
func may_equip(id: String, groups: PackedStringArray, entitlements: PackedStringArray = PackedStringArray()) -> GSResult:
	var def := get_def(id)
	if def == null:
		return GSResult.fail(GSError.CODE_INVALID, "unknown trail", id)
	if def.access == GSTrailDef.ACCESS_PUBLIC and def.price == 0:
		return GSResult.success(def)
	if entitlements.has(id):
		return GSResult.success(def)
	if def.access == GSTrailDef.ACCESS_GROUPS:
		for g in def.groups:
			if groups.has(g):
				return GSResult.success(def)
	return GSResult.fail(GSError.CODE_FORBIDDEN, "trail is not available to this player", id)


func describe() -> String:
	return "GSTrailRegistry: %d trails, %d images" % [_defs.size(), _images.size()]


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray([describe()])
	for id in ids():
		out.append("  " + get_def(id).describe())
	return out
