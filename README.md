# PiP Solver

Omarchy service plugin that fixes picture-in-picture windows on Hyprland, for every app that creates them.

Each PiP window (matched by title — Firefox, Chromium, Brave, Edge, Zen, forks, Google Meet):

- opens floating and pinned, so it stays on top of other windows
- keeps the video aspect ratio when resized — the image always fills the window, never cropped
- gets a grabbable border, so you can resize it from its edges
- holds an idle inhibitor while it exists — no screensaver and no lock while a PiP is open

## Install

```sh
omarchy plugin add https://github.com/rfranco-ti/pip-solver.git --enable
```

## Optional: resize by hovering the edges

```lua
-- ~/.config/hypr/looknfeel.lua
hl.config({
  general = {
    resize_on_border = true,
  },
})
```

## Diagnostics

```sh
omarchy-shell pip-solver status
```

## Remove

```sh
omarchy plugin remove ricardo-ti.pip-solver
```
