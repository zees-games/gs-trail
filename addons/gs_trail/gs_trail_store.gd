class_name GSTrailStore
extends RefCounted

## A server's trails on disk and the one pack built from them. The store directory is the pack source: trails.json, the images and licence.json, so what the workbench saves is exactly what the pack builder publishes.

const CHANNEL := "trail"
const LICENCE_FILE := "licence.json"
## The licences the site accepts for CDN content (gs-cloud docs/cdn-publish.md).
const LICENCES := ["CC0-1.0", "MIT", "Unlicense", "public-domain", "CC-BY-3.0", "CC-BY-4.0"]

var registry: GSTrailRegistry
var dir: String = ""


func _init(p_registry: GSTrailRegistry = null, p_dir: String = "") -> void:
	registry = p_registry if p_registry != null else GSTrailRegistry.new()
	dir = p_dir


## The upload form's core. [param meta] is the def's dictionary (id, title, width, access, groups, price, licence, author, url...); the image name is derived from the id and the sniffed type. Value on success: the GSTrailDef.
func submit(meta: Dictionary, image_bytes: PackedByteArray, declared_name: String = "") -> GSResult:
	var id := str(meta.get("id", ""))
	if not GSTrailDef.valid_id(id):
		return GSResult.fail(GSError.CODE_INVALID, "trail id must be 1-32 chars of a-z, 0-9, _", id)
	if not LICENCES.has(str(meta.get("licence", ""))):
		return GSResult.fail(GSError.CODE_INVALID, "licence must be one of " + ", ".join(LICENCES), id)
	var url := str(meta.get("url", ""))
	if str(meta.get("author", "")).strip_edges().is_empty() or not (url.begins_with("https://") or url.begins_with("http://")):
		return GSResult.fail(GSError.CODE_INVALID, "an author and an http(s) url are required", id)
	var ext := declared_name.get_extension().to_lower() if not declared_name.is_empty() else "png"
	var checked := GSTrailUpload.validate(image_bytes, id + "." + ext, registry.config.limits())
	if not checked.ok:
		return checked
	var d := meta.duplicate()
	d["image"] = id + "." + str(checked.value["type"])
	var made := GSTrailDef.from_dict(d, registry.config.limits())
	if not made.ok:
		return made
	var def: GSTrailDef = made.value
	if def.credit.is_empty():
		def.credit = "%s (%s)" % [def.author, def.licence]
	var old := registry.get_def(id)
	if old != null:
		registry.remove(id)
	var added := registry.add(def, image_bytes)
	if not added.ok and old != null:
		var _back := registry.add(old, registry.image_bytes(id))
	return added


## Writes trails.json, the images and licence.json into [member dir] (or [param to]). Removes images no trail names any more.
func save(to: String = "") -> GSResult:
	var target := to if not to.is_empty() else dir
	if target.is_empty():
		return GSResult.fail(GSError.CODE_INVALID, "trail store has no directory")
	var made := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	if made != OK:
		return GSResult.fail(GSError.CODE_IO, "cannot create " + target)
	var files := registry.pack_files()
	files[LICENCE_FILE] = licence_json().to_utf8_buffer()
	for old in DirAccess.get_files_at(target):
		if not files.has(old):
			DirAccess.remove_absolute(target.path_join(old))
	for name: String in files:
		var f := FileAccess.open(target.path_join(name), FileAccess.WRITE)
		if f == null:
			GSLog.error(CHANNEL, "trail store write failed", {"file": name, "dir": target})
			return GSResult.fail(GSError.CODE_IO, "cannot write " + name, target)
		f.store_buffer(files[name])
		f.close()
	GSWeb.sync_filesystem()
	return GSResult.success(files.size())


## Loads a store or a mounted pack directory into [member registry]. A directory without trails.json is an empty store, not an error.
func load_dir(from: String = "") -> GSResult:
	var src := from if not from.is_empty() else dir
	var index_path := src.path_join(GSTrailRegistry.INDEX_FILE)
	if not FileAccess.file_exists(index_path):
		return GSResult.success(0)
	var files := {}
	for name in DirAccess.get_files_at(src):
		var ext := name.get_extension().to_lower()
		if ext == "png" or ext == "webp":
			files[name] = FileAccess.get_file_as_bytes(src.path_join(name))
	return registry.load_index(FileAccess.get_file_as_string(index_path), files)


## The pack's licence.json: one entry per image, so the site's licence gate covers every file.
func licence_json() -> String:
	var entries: Array = [{"paths": [GSTrailRegistry.INDEX_FILE, LICENCE_FILE], "licence": "CC0-1.0", "author": "gs-trail", "url": "https://github.com/zees-games/gs-trail"}]
	for id in registry.ids():
		var d := registry.get_def(id)
		entries.append({"paths": [d.image], "licence": d.licence, "author": d.author, "url": d.url})
	return JSON.stringify(entries, "\t")
