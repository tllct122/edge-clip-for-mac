# EdgeClip ✿

**English** | [繁體中文](README.zh-Hant.md) | [简体中文](README.zh-Hans.md)

**Clipboard history that hides at the edge of your Mac screen.**

You copied something ten minutes ago and now it's gone. EdgeClip remembers everything you copy and keeps it in a thin panel tucked into the left edge of your screen. Move your mouse there (or press ⌥⌘V) and it slides out — click a clip to copy it again.

<!-- Add a demo GIF here: ![demo](docs/demo.gif) -->

## Features

- 🫧 **Hover to peek** — hides at the screen edge, slides out on hover
- ⌨️ **Keyboard first** — ⌥⌘V opens it, type to search, ↑↓ to choose, Return to copy, ⌘1–9 for the first nine clips
- ⚡ **Paste right away** (optional) — pick a clip and it's pasted straight into the app you're using
- ★ **Star your favorites** — email templates, addresses, links you always reuse. Starred clips stay at the top, can be named, and are never cleared
- 🔍 **Search & filter** — All / Text / Links / Images / Colors
- 🖼 **Understands what you copied** — images get thumbnails, colors get a swatch (`#AF52DE`), links are highlighted, files show their names, and each clip shows the app it came from
- 🔒 **Private by default** — passwords that password managers mark as private are never saved, you can block whole apps, pause recording anytime, and everything stays on your Mac
- 📌 **Pin it open** — pinned panel turns into Liquid Glass (macOS 26+)
- 🎨 **Customize everything** — fonts (any font on your Mac), weight, size, text & accent colors, tint, opacity, size, corner radius, left or right edge, top / middle / bottom
- 🪶 **Tiny & native** — a single Swift file, no dependencies, no account, no cloud

Works great next to [EdgeTodo](https://github.com/tllct122/edge-todo-for-mac) — EdgeClip on the left, EdgeTodo on the right, so they never overlap.

## Install

Requires macOS 12 or later (Liquid Glass needs macOS 26+).

1. Download this repo (**Code → Download ZIP**) and unzip it
2. Open **Terminal**, type `bash ` (with a space), drag `build.sh` into the window, press Enter
3. If macOS asks you to install **Command Line Tools**, install them and run step 2 again

The script builds the app, installs it to `/Applications`, and launches it.

## Usage

| Action | How |
|---|---|
| Open the panel | Move your mouse to the left edge of the screen (upper half), or press **⌥⌘V** |
| Copy a clip again | Click it |
| Use the keyboard | **↑ ↓** to move, **Return** to copy, **⌘1–9** for the first nine, **Esc** to close, **⌘⌫** to delete |
| Search | Type in the search box at the top |
| Star a clip | Hover it and click ☆ |
| Name a starred clip | Right-click → **Name…** |
| Open a link / show a file | Right-click → **Open Link** / **Show in Finder** |
| Pause recording | Click "clipboard" at the top of the panel, or the 📋 menu bar icon → **Pause Recording** |
| Clear history | Click **clear** at the bottom (starred clips stay) |
| Keep it open | Click 📌 |
| Settings | Click ⚙︎ on the panel, or the 📋 menu bar icon → **Settings…** (⌘,) |
| Launch at login | 📋 menu bar icon → **Open at Login** |

### Paste right away

Turn on **Settings → Clipboard → Paste right away when I pick a clip**. macOS will ask you to allow EdgeClip in **System Settings → Privacy & Security → Accessibility** — this is what lets it press ⌘V for you. Without it, clips are still copied and you press ⌘V yourself.

> After installing an update, you may need to switch EdgeClip off and on again in that Accessibility list.

## Privacy

- Your history is stored only in `~/EdgeClip/history.json` (images in `~/EdgeClip/images/`). Nothing is sent anywhere.
- Copies marked as private by password managers (1Password, Bitwarden, and others that follow the [nspasteboard.org](http://nspasteboard.org) convention) are skipped.
- By default, copies from 1Password, Bitwarden, Keychain Access, Passwords, Dashlane and LastPass are ignored. Edit the list in **Settings → Clipboard**.
- Click "clipboard" at the top of the panel to pause recording at any time.

## Build manually

```bash
swiftc -O -parse-as-library EdgeClip.swift -o EdgeClip
```

Add `-D GLASS` when building against the macOS 26+ SDK to enable Liquid Glass. `build.sh` handles this and also works around mismatched SDK / compiler versions. Build it as an app with `build.sh` for the shortcut and Accessibility features to work properly.

## Support

If EdgeClip saves you a few re-copies a day, you can support it here:

- ☕ Buy Me a Coffee: https://buymeacoffee.com/sirene122

## License

[MIT](LICENSE)
