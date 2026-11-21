# dot-trail

Equippable player trails: an image ribbon that follows a node. Read [docs/design.md](docs/design.md) first; it holds the reuse map, the data model, the equip rule and the store contract for the TMC backend.

**The distributable is `addons/dot_trail/`.** `project.godot` and `examples/` exist to validate it alone. It requires dot-core and, for the parts that extend official addons, dot-workbench, dot-game and dot-net (symlinks in `addons/`, gitignored). **The dependency runs one way: dot-trail extends dot-workbench and dot-game through their generic hooks; neither knows trails exist.** dot-cloud is reached by path.

| Path | What |
| --- | --- |
| `dot_trail_def.gd` | `GSTrailDef`: one trail, `from_dict` checks every field |
| `dot_trail_upload.gd` | `GSTrailUpload.validate`: png/webp by magic bytes, size, dimensions, nothing after the image; pure |
| `dot_trail_registry.gd` | `GSTrailRegistry`: the set, `trails.json` index, pack file list, the access rule `may_equip`; installed through `GSRegistry` |
| `dot_trail_equip.gd` | `GSTrailEquip`: server-side who wears what, cooldown, `revalidate` |
| `dot_trail_ribbon.gd` | `GSTrailRibbon.strip`: ribbon geometry as a pure function |
| `dot_trail_emitter.gd` | `GSTrailEmitter`: follows a node via `GSNodeRef`, keeps points headless, draws only with a display |
| `dot_trail_store.gd` | `GSTrailStore`: the upload form's core (`submit` needs licence from the CDN list, author, url), the store directory = the pack source (trails.json, images, licence.json) |
| `dot_trail_pack.gd` | `GSTrailPack`: `build` publishes the store as ONE dot-cloud pack (publisher by path), `fetch` ensures it through a GSCloudClient and loads it |
| `workbench/dot_trail_workbench.gd` | `GSTrailWorkbench`: ops `trail_list/upload/delete`, flag `trail`, `/api/trails`, built on `GSWorkbenchHttp.mount_extension` and `GSWorkbenchApi.add_flag` |
| `net/dot_trail_message.gd`, `net/dot_trail_relay.gd` | `GSTrailMessage` (id only) and `GSTrailRelay`: the server checks a request through `GSTrailEquip` and tells everyone; a joiner hears who wears what; `revalidate` |
| `client/dot_trail_client.gd` | `GSTrailClient`: `attach(net, registry)`, `request(id)`, one emitter per wearer, `fetch_pack`; rule `sv_trail_pack=<id>@<version>` (`PACK_CVAR`), registered on the server console by `advertise(console, config)` as a notify cvar |
| `net/dot_trail_envelope.gd` | `GSTrailEnvelope`: the same relay over a dot-server envelope kind `dot.trail` (`serve` on the server with an optional `refresh_fn` before a refusal, `attach` on a client link) |
| `store/` | `GSTrailBackend` (catalog, purchase, set_equipped, submit_upload, entitlements, server_catalog; `explain`), `GSTrailBackendHttp` (the site, configurable paths), `GSTrailBackendStub` (tests, offline) |
| `ui/` | The in-game store: `GSTrailScreen` (grid, buy, equip), `GSTrailUploadPanel`, `GSTrailPreview` (live ribbon), `GSTrailFilePick` (desktop dialog or browser input), `GSTrailKit` (dot-menu look with a fallback), `GSTrailMenu.add_to(menu, setup)` |
| `dot_trail_config.gd` | `GSTrailConfig`: cvars (`DOT_TRAIL_*`, `--trail-*`); `pack` (`--trail-pack`) is the `<id>@<version>` a server advertises, checked by `parse_pack` |

- Prices, purchases and entitlements belong to the TMC backend. Every HTTP call is in `store/dot_trail_backend_http.gd` and follows the contract in the design note; change both together.
- Images are only ever read through `Image.load_*_from_buffer` after `GSTrailUpload.validate`; never load a pack's file as a resource.
- The addon ships no art; uploaders are responsible for the rights to what they upload.
- Validate: import, `--check-only` on every `.gd`, then `res://examples/trail_selftest.tscn` (8 sections, 98 checks), `workbench_selftest.tscn` (3 sections, 26 checks), `net_selftest.tscn` (24 checks) and `http_selftest.tscn` (5 sections, 29 checks: every site route against a mocked GSHttp), `cloud_selftest.tscn` (4 sections, 17 checks: build, sign, advertise, then a started GSCloudClient fetches and mounts the pack through `GSGamePrejoin.extra_steps`, all from a local CDN directory), `ui_selftest.tscn` (6 sections, 62 checks: envelope, stub store, screen, good and bad uploads, submit), `tools/screenshot.sh out.png` renders a runner with trails and `tools/screenshot_ui.sh <prefix>` the store page and upload form (display needed), all through `heavy`. dot-menu, dot-ui and dot-settings are linked for the UI suite and shots. CI is the shared dot-ci `@v1`.

Wiring in a game (needs dot-game API level 31, which adds `extra_steps`): add `client.fetch_pack` to dot-game's `GSGamePrejoin.extra_steps` (`func(rules): return await trail_client.fetch_pack(cloud, rules)`; a failure is a warning and the join goes ahead), and `GSTrailWorkbench.new(api, store).mount(http)` for the owner/admin form. A server sets `pack` (`--trail-pack trails-x@1.0.0`) and calls `GSTrailClient.advertise(console, config)` once its console exists; publish the store directory with dot-cloud's `tools/publish_pack.sh --source <dir> --id trails-<server>` or `GSTrailPack.build`.
