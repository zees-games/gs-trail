![Trails banner](https://raw.githubusercontent.com/zees-games/gs-trail/main/docs/banner.png)

Players equip a trail, an image ribbon that follows them as they move. Operators upload trails and choose who may wear them: everyone, or only some groups (donators, say). The server decides what a player may wear, and clients download every trail as one pack before joining. Design notes: [docs/design.md](docs/design.md).

GameSpice addon, MIT, built with Claude Code. `trail_selftest.tscn`, `ui_selftest.tscn` and `http_selftest.tscn` in `examples/` run headless. The games in [Zee's Games](https://zeesgames.com) are built on GameSpice addons and run on live servers; this addon is not in any of them yet. Bug reports go to the [issue tracker](https://github.com/zees-games/gs-trail/issues).

**Licensing: this addon provides upload and display only. It ships no art; whoever uploads an image is responsible for having the right to distribute it.**

## Install

1. Get [Godot 4.7](https://godotengine.org/download).
2. Either use [gs-bootstrap](https://github.com/gamespice-platform/bootstrap), which clones every project and links the addons, or copy `addons/gs_trail/` and its dependencies into your project and enable gs-trail in *Project > Project Settings > Plugins*.

## Use

```gdscript
var trails := GSTrailRegistry.new()
trails.install()                                   # GSRegistry, no autoload
trails.load_index(index_json, files)               # the downloaded pack
var equip := GSTrailEquip.new(trails)
var res := equip.equip(peer_id, "spark", groups, entitlements)   # GSResult; server only

var emitter := GSTrailEmitter.new()               # child of the player, or set `target`
emitter.registry = trails
player.add_child(emitter)
emitter.set_trail(trails.get_def(equip.worn(peer_id)))
```

## Settings

`GSTrailConfig`, layered as file, then `GS_TRAIL_*` environment, then `--trail-*` command line.

| Setting | Default | Meaning |
| --- | --- | --- |
| `enabled` | true | Trails on or off. |
| `min_step` | 0.15 | Distance moved before a new ribbon point. |
| `max_points` | 64 | Points kept per ribbon, which sets its length. Any value; 0 is unlimited (lifetime alone bounds it). 1 is refused. |
| `equip_cooldown` | 1.0 | Seconds between equip changes. |
| `max_trails` | 256 | Trails the registry accepts. Any value; 0 is unlimited. |
| `max_upload_bytes` | 262144 | Largest uploaded image. Any value; 0 is unlimited. |
| `max_dimension` | 512 | Largest image side in pixels. Any value; 0 is unlimited. |
| `max_width` | 2.0 | Widest ribbon a trail may ask for, in metres. Any value; 0 is unlimited. |
| `max_lifetime` | 5.0 | Longest ribbon lifetime a trail may ask for, in seconds. Any value; 0 is unlimited. |
| `cull_distance` | 60 | Distance beyond which a ribbon is not drawn. 0 is never culled. |

These are limits you can change, and like other GameSpice settings 0 means unlimited. A negative value is refused when the config is validated, never clamped.

## Testing

Import the project once, then run `trail_selftest.tscn`, `ui_selftest.tscn` and `http_selftest.tscn` (the site routes against a mocked HTTP layer) in `examples/` headless with Godot.

## Used by

### Zee's Games

Zee's Games is a collection of games I made on GameSpice, for demonstration and for fun. They show what the platform can do, and they run on live servers you can join. Anybody can create games on GameSpice, and each addon is its own repository and can be used separately from the games and from the rest of GameSpice.

No shipped game uses it yet; the example scene shows it.

The whole collection is at [zeesgames.com](https://zeesgames.com).

## Credits

| Item | Source |
| --- | --- |
| Trail art | None shipped. Every trail carries a `credit` (author, licence and source URL), required by the upload form and shown in the store. |
| Store page, ribbon previews, screenshots in `docs/` | Drawn by the addon's own code from generated noise and flat colours. No third-party image is bundled. |
| Engine and addons | Godot Engine (MIT) and the gs-core, gs-game, gs-net, gs-menu, gs-ui and gs-cloud addons of this family. |
| Site routes | The TMC site's trail routes: `/api/app/v1/trails` for players and `/api/integration/v1/trails` for the game server. |

## Licence

MIT licence, see [LICENSE](LICENSE). The only closed part of the [**GameSpice**](https://gamespice.net) platform is the web back end; you can use your own instead of GameSpice's.
