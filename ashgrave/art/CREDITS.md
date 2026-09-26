# Art credits

Ashgrave's code is original. Its character and creature art comes from two open-licensed projects. All of it may be used, modified and redistributed, including commercially, **as long as the authors are credited and modified art stays under the same license (share-alike)**.

## People: Liberated Pixel Cup (LPC)
Every human (Maren, companions, villagers, bandits, cultists, the Ashen Knight) is assembled from layers of the
[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).
Layers were recoloured and composited by `tools/import_lpc.py`. Each source file's authors, licenses (CC-BY-SA 3.0, OGA-BY 3.0, GPL 3.0 — used under CC-BY-SA / OGA-BY where offered) and links are listed in [`lpc/CREDITS_LPC.csv`](lpc/CREDITS_LPC.csv).

## Monsters and portraits: Flare
Skeletons, zombies, goblins, ants, antlions, graves and the painted portraits come from
[Flare](https://github.com/flareteam/flare-game) (`fantasycore` and `empyrean_campaign`), licensed
[CC-BY-SA 3.0](flare/LICENSE_CC-BY-SA-3.0.txt). Frames were scaled, repacked and palette-reduced by
`tools/import_flare.py`. Artists are listed in [`flare/CREDITS_FLARE.txt`](flare/CREDITS_FLARE.txt).

## Regenerating
```sh
python3 tools/import_lpc.py      # needs Pillow + git; fetches only the layers it uses
python3 tools/import_flare.py
```
