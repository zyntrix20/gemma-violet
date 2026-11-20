# Funkin Mod Engine (Android)

A Friday Night Funkin' engine for Android, built on [Psych Engine](https://github.com/ShadowMario/FNF-PsychEngine) 1.0.4.
It ships **without songs**: every song comes from a mod that you import on the phone.

## Features

- **Mods → IMPORT MOD (.ZIP)**: pick a mod archive with the system file picker. The engine extracts it,
  converts it if needed and adds its songs to Freeplay and Story Mode with their characters, stages, icons and music.
- Supported mod formats:
  | Format | What is converted |
  |---|---|
  | **Psych Engine** (0.4 – 1.0) | Used as is: charts, Lua and HScript, characters, stages, weeks, videos |
  | **V-Slice** (Funkin' 0.3+, Polymod) | Charts and metadata (all difficulties), variations (Erect, Pico mix…) as separate songs, vocals, characters (Sparrow / multi-atlas / Animate), stages (prop layout, zIndex, character anchors, camera offsets, bopping props), weeks (`data/levels`), camera events (`FocusCamera`, `ZoomCamera`, `SetCameraBop`), `PlayAnimation`, `ScrollSpeed` |
  | **Codename Engine** | Charts (strumlines, note types, camera/BPM events), `meta.json`, vocals, character XML, stage XML, weeks |
  | Full game folders | Archives of a whole mod build (`assets/` or `mods/` inside) are detected automatically |
- Touch controls: D-pad + A/B/C/X/Y in menus, a 4-lane hitbox, a pause button and a SPACE button in gameplay.
  Touches are sent as the keys bound in Options, so mod scripts that read the keyboard keep working.
  The Android back button works as Back / Pause.
- Default characters, stages and menu art are included, so mods that rely on `bf`, `gf`, `dad`, `stage`… work.

### Scripts from other engines

- **Codename Engine** scripts (`.hx`) run through a compatibility layer: Codename callback names
  (`create`, `postCreate`, `beatHit`, `onPlayerHit`, `onDadHit`, `onEvent`, `onStartCountdown`…) are mapped
  to Psych's, and common helpers (`stage.getSprite`, stage sprites by name, `strumLines`) are provided.
- **V-Slice** scripts (`.hxc` classes) are translated at import into plain HScript and run with V-Slice-like helpers
  (`PlayState.instance.currentStage.getNamedProp`, `Conductor.instance`, `FunkinSprite`, `VideoCutscene.play`…).
- Simple stage effects, cutscene timers and animation triggers usually work. Scripts that depend on engine
  internals that Psych doesn't have will show an error line in the song and are switched off instead of crashing.
- Mods that change the engine's **source code** (distributed only as compiled `.exe` builds) cannot be loaded.
- `.rar` / `.7z` archives must be re-packed as `.zip`.

## Installing

Download `FunkinModEngine.apk` from the [Releases](../../releases) page and install it on your phone
(allow installing from unknown sources). On first launch the engine unpacks its built-in files once.

Mods can also be copied by hand into
`Android/data/org.funkinmods.engine/files/mods/` on your phone's storage.

## Building

APKs are built by GitHub Actions (`.github/workflows/android.yml`) on every push and published as a release.

To keep the same signing key between builds (so updates install over the old version), add two repository secrets:
`KEYSTORE_BASE64` (a base64-encoded keystore) and `KEYSTORE_PASSWORD`. Without them each build is signed with a new
throwaway key, and you need to uninstall the old version before installing a new one.

Local build: install Haxe 4.3.4, the libraries listed in the workflow, the Android SDK, NDK r21e and JDK 17, then run
`haxelib run lime build android -final`.

## Code map

| Path | What it does |
|---|---|
| `source/mobile/` | Storage folder setup and first-launch asset copy, touch controls, native bridge |
| `android/modtools/` | Small Java extension: storage path and system file picker |
| `source/modding/ModImporter.hx` | Finds mods inside an archive, detects the format, extracts and converts |
| `source/modding/VSliceConverter.hx` | V-Slice → Psych conversion |
| `source/modding/CodenameConverter.hx` | Codename Engine → Psych conversion |
| `source/modding/CompatRuntime.hx` | In-game support for converted V-Slice stages and camera events |
| `source/states/ModsHubState.hx` | The Mods screen |

## Credits

- Psych Engine by Shadow Mario, Riveren and contributors (Apache 2.0). See the original credits in the game.
- Friday Night Funkin' by the Funkin' Crew. The characters, art and sounds belong to them.
  This is a free, non-commercial fan project.
