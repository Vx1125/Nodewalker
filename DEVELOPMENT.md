# Developing Nodewalker

- UI rules: [UI_DESIGN_STANDARD.md](UI_DESIGN_STANDARD.md)
- CurseForge page text: [CURSEFORGE.md](CURSEFORGE.md) (paste into the project description)
- Gallery, GIFs and claims to check in game: [MARKETING.md](MARKETING.md)

## Releasing

1. Add the changes to `CHANGELOG.md`, one short line each.
2. Put the new version in `VERSION` (e.g. `1.1.21`) and push to `main`.
   The GitHub Action tags `v1.1.21`, packages the addon and uploads it to CurseForge.
   Pushing a `v1.1.21` tag works too.
3. If a release run sits queued with no jobs, don't re-run it without checking: it once uploaded twice.

Needs the repository secret `CF_API_KEY` (a CurseForge API token), and
Settings › Actions › General › Workflow permissions set to "Read and write".

## Debug commands

| Command | Does |
|---|---|
| `/nw terrain` | Which minimap tiles this zone uses |
| `/nw continent <id> <folder>` | Point a continent at a minimap folder |
| `/nw frame` | Names the frame under the mouse |
| `/nw harvest` · `/nw harvest all` | Saves the game's level and effect text for consumables |
