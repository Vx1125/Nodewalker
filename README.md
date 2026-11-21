# Nodewalker

All-in-one professions addon for WoW Forever: a Diablo-style farming overlay, gathering routes, and leveling guides for every profession priced from the auction house.

CurseForge project: (set in `Nodewalker.toc` as `X-Curse-Project-ID`)

## Releasing

1. Update `CHANGELOG.md`.
2. Put the new version number in `VERSION` (e.g. `1.0.1`) and push to `main`.
   The GitHub Action tags `v1.0.1`, packages the addon and uploads it to CurseForge.
   (Pushing or creating a `v1.0.1` tag on GitHub works too.)

Needs the repository secret `CF_API_KEY` (a CurseForge API token), and
Settings > Actions > General > Workflow permissions set to "Read and write".

## Commands

`/nw` overlay, `/nw plan` route, `/nw guide` herb guide, `/nw prof` professions, `/nw options`,
`/nw import` (GatherMate2), `/nw next`, `/nw status`, `/nw hide <herb>`, `/nw show <herb>`, `/nw frame`.

## Credits

Minimap tile tables in `OpenMapData/` come from [OpenMap](https://github.com/openmap-world/openmap) (MIT, see `LICENSES/`).
Recipe data: SeeMeta's WoW Forever recipe database.
The full recipe list, sources and trainer fees are derived from [One For All](https://www.curseforge.com/wow/addons/oneforall) by Smoergi (GPL-3.0-or-later, see `LICENSES/`).

## License

GPL-3.0-or-later. See `LICENSE`.
