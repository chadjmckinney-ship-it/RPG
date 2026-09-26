# Art credits

Ashgrave's code is original. Its art comes from open-licensed projects. All of it may be used, modified and redistributed, including commercially, **as long as the authors are credited** (and, for the CC-BY-SA LPC layers, modified art stays under the same license).

## People: Liberated Pixel Cup (LPC)
Every character and creature (Maren, companions, villagers, bandits, cultists, skeletons, zombies, beast-folk, the bosses) is assembled from layers of the
[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).
Layers were recoloured and composited by `tools/import_lpc.py`. Each source file's authors, licenses (CC-BY-SA 3.0, OGA-BY 3.0, GPL 3.0 — used under CC-BY-SA / OGA-BY where offered) and links are listed in [`lpc/CREDITS_LPC.csv`](lpc/CREDITS_LPC.csv).

## World: Eliza Wyatt's revised LPC set
Ground textures, trees, rocks, plants, village props, the cottages and the landmark pieces come from
[ElizaWy/LPC](https://github.com/ElizaWy/LPC) (Eliza Wyatt, Lanea Zimmerman "Sharm", Hyptosis and others; OGA-BY 3.0 / CC-BY 3.0+ / CC0).
They were cropped, graded darker and recomposited by `tools/import_world.py` (cottages re-skinned with stone walls; the barrow,
chapel and watchtower assembled from rocks, walls and pillars). Per-folder artist credits are in [`world/CREDITS_WORLD.txt`](world/CREDITS_WORLD.txt).

## Portraits
Portraits are head-and-shoulder crops of each character's own LPC sprite (above), drawn by `ui/portraits.gd`.

## Item icons and UI
Item icons are cut from Eliza Wyatt's LPC small items ([ElizaWy/LPC](https://github.com/ElizaWy/LPC), OGA-BY 3.0 / CC-BY 3.0+;
per-folder credits for `Objects/Small Items` apply) and from the baked LPC outfits; weapon and coin icons and the panel frames
are original pixel art. All made by `tools/import_ui.py`.

## Fonts
[Jersey 10](https://github.com/google/fonts/tree/main/ofl/jersey10) (The Soft Type Project Authors) for text and
[UnifrakturCook](https://github.com/google/fonts/tree/main/ofl/unifrakturcook) (j. 'mach' wust) for titles, both under the
SIL Open Font License 1.1 ([`ui/fonts/`](ui/fonts/)).

## Regenerating
```sh
python3 tools/import_lpc.py      # needs Pillow + git; fetches only the layers it uses
python3 tools/import_world.py
python3 tools/import_ui.py
```
