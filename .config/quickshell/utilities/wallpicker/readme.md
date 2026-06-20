# Chaos WallPicker

![Chaos Wallpaper](./assets/logo.svg)


This is intended to be a part of my `under construction` shell : **Chaos Shell - by rel-9**

A wallpaper picker built with Quickshell + QML. It shows your wallpapers in a smooth carousel thingy at the bottom of the screen, you pick one, it sets it. That's it. Nothing fancy, nothing complicated. This is a wayland specific, WM independent, standalone wallpaper picker. Thanks to the unixporn community for dumping lots of dots, I integrated this piece by piece, having partially learnt `QML`, yet successfully built a working wallpaper picker. Honestly, these are my idea + configuration + other's qml programmings. 

## Show Case 

**Top Anchored**

![Top Anchored](./assets/top.png)

**Center Anchored**

![Center Anchored](./assets/center.png)

**Bottom Anchored**

![Bottom Anchored](./assets/bottom.png)

**With Background Color**

![With Background Color](./assets/background.png)

**Ah, More Images!!**

![More Images](./assets/more.png)

## What you need installed

Before anything, make sure you have these: `quickshell`, `imagemagick`, `jq`, `awww`, `matugen`. I am not gonna explain what each does, you probably already know. If something breaks, it's likely one of these missing.
If you use `arch` btw, or any `arch based distro` btw,or any other distro which uses `pacman` as it's package manager, never bother to check if it is installed if else install by  : 

```bash 
sudo pacman -S --needed quickshell imagemagick jq awww(or whatever you love to use) matugen(optional, I use dynamic theming for qs in my workflow, hence.)
```

If you are a wayland person not being an `Arch (Wo)Man`; You can either `sudo apt` it or install it with your package manager stuff, based on your distro base. You are now set to go and play with some random wallpapers.

## File structure

Keep it like this, don't move things around randomly:
If you are good enough to spin up a qmldir or use relative imports, feel free to integrate in your shell.

```
wallpaper-picker/
├── shell.qml
├── config.json
├── cache.sh
└── commands.sh
```

### config.json — read this carefully

This is the only file you actually need to touch before running. Open it and set your own paths:
Without this, you would see nothing. Also, make sure you cached your images by cache command.

```json
{
    "wallpaper_path": "/path/to/your/wallpapers/",
    "cache_path": "/path/to/.cache/thumbs/",
    "number_of_pictures": 7,
    "border_color": "#C27B63",
    "cache_batch_size": 20
}
```

`wallpaper_path` — where your wallpapers actually live. `cache_path` — where the thumbnails get saved, keep it somewhere inside `~/.cache/` like a sane person. `number_of_pictures` — how many show up in the carousel, 7 feels right, don't go too high. `border_color` — the glowy border on the selected one, any hex color works. `cache_batch_size` — parallel jobs for thumbnail generation, 20 is fine, lower it if your PC starts crying.


### cache.sh — run this first, seriously

The picker doesn't load your original wallpapers directly — that would be painfully slow. It loads small thumbnails from your cache folder. So before launching the picker for the first time, you gotta generate those thumbnails, else, you would end up staring at the blank screen or a shadow of thumbnail:

```bash
bash cache.sh ~/.config/quickshell/wallpaper-picker
```

Just pass the folder where your `config.json` lives. It'll read the config, find all your `.jpg`/`.jpeg`/`.png` files, and cook up 500px thumbnails into your cache folder. Already cached ones get skipped, so running it again after adding new wallpapers is totally safe:

```bash
# added new wallpapers? just run it again, it won't redo the old ones
bash cache.sh ~/.config/quickshell/wallpaper-picker
```

### Running it

```bash
quickshell -p ~/.config/quickshell/wallpaper-picker
# alternatively use qs if you do not like typing more; qs == quickshell
```

Done. The overlay pops up at the bottom of your screen. You can also tweak where you want the wallpaper picker to pop : change the bool values to false. that's it. If you need some background for the wallpaper picker, you can set the transparent -> some color in PanelWindow. 

### Controls

Pretty simple honestly:

| Key | What it does |
|-----|-------------|
| `←` or `h` | go left |
| `→` or `l` | go right |
| `Enter` or `Space` | set wallpaper and close |
| `Escape` | close without doing anything |

You can also just click a thumbnail directly if you don't wanna use keyboard.


### commands.sh — how the wallpaper actually gets set

When you press Enter, this script runs with your selected wallpaper path. Right now it does two things:

```bash
awww img $1 -t grow --transition-duration 1
matugen image $1 --source-color-index 0 --json hex > ~/.config/wayfire/assets/shared/colors.json
```

First line sets the wallpaper with a nice grow transition via `awww`. Second line runs `matugen` to generate a color scheme from the wallpaper and dumps it into your colors file. If you use `swww` or `hyprpaper` or something else instead of `awww`, just swap that line out. The rest stays the same.


## Adding wallpapers later

Drop them in your `wallpaper_path` folder, run `cache.sh` again, done. The picker reads the folder live so new ones show up automatically next launch.
This is a standalone qs which works pretty well in ANY configuration without much compications. Features may be added in the future, as I learn MORE QML.
