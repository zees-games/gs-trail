extends RefCounted

## dot-trail's API level; the bump rule is on GSAddonApi in dot-core.

# 1: GSTrailDef, GSTrailRegistry, GSTrailEquip, GSTrailUpload, GSTrailRibbon, GSTrailEmitter, GSTrailConfig.
# 2: GSTrailWorkbench, GSTrailMessage, GSTrailRelay, GSTrailClient (moved here from dot-workbench and dot-game).
# 3: GSTrailEnvelope, GSTrailBackend (Stub, Http), the store UI (GSTrailScreen, GSTrailUploadPanel, GSTrailPreview, GSTrailFilePick, GSTrailKit, GSTrailMenu), relay receive/allows, client receive/apply_missing.
# 4: GSTrailBackend.server_catalog and set_equipped; GSTrailBackendHttp follows the site's /api/app/v1/trails and /api/integration/v1/trails routes.
const LEVEL := 4
const OLDEST := 1
