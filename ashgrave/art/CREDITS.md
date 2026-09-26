# Art credits

Ashgrave's code is original. Its art comes from open-licensed projects. All of it may be used, modified and redistributed, including commercially, **as long as the authors are credited and modified art stays under the same license (share-alike)**.

## People: Liberated Pixel Cup (LPC)
Every character and creature (Maren, companions, villagers, bandits, cultists, skeletons, zombies, beast-folk, the bosses) is assembled from layers of the
[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).
Layers were recoloured and composited by `tools/import_lpc.py`. Each source file's authors, licenses (CC-BY-SA 3.0, OGA-BY 3.0, GPL 3.0 — used under CC-BY-SA / OGA-BY where offered) and links are listed in [`lpc/CREDITS_LPC.csv`](lpc/CREDITS_LPC.csv).

## World: Eliza Wyatt's revised LPC set
Ground textures, trees, rocks, plants, village props, the cottages and the landmark pieces come from
[ElizaWy/LPC](https://github.com/ElizaWy/LPC) (Eliza Wyatt, Lanea Zimmerman "Sharm", Hyptosis and others; OGA-BY 3.0 / CC-BY 3.0+ / CC0).
They were cropped, graded darker and recomposited by `tools/import_world.py` (cottages re-skinned with stone walls; the barrow,
chapel and watchtower assembled from rocks, walls and pillars). Per-folder artist credits are in [`world/CREDITS_WORLD.txt`](world/CREDITS_WORLD.txt).

## Portraits: Flare
The painted portraits come from
[Flare](https://github.com/flareteam/flare-game) (`fantasycore` and `empyrean_campaign`), licensed
[CC-BY-SA 3.0](flare/LICENSE_CC-BY-SA-3.0.txt). They were resized by `tools/import_flare.py`. Artists are listed in [`flare/CREDITS_FLARE.txt`](flare/CREDITS_FLARE.txt).

## Regenerating
```sh
python3 tools/import_lpc.py      # needs Pillow + git; fetches only the layers it uses
python3 tools/import_flare.py
python3 tools/import_world.py
```
