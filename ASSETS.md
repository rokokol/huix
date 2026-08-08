# Assets and third-party content

`LICENSE` (MIT) covers the **code** in this repository — Nix modules, shell scripts, QML, CSS and configuration. It does **not** cover the artwork, fonts and text listed here, which belong to their respective owners and are included as fan content.

## Doki Doki Literature Club

Doki Doki Literature Club and Doki Doki Literature Club Plus are the property of [Team Salvato](https://teamsalvato.com/). This project is **unaffiliated with and not endorsed by Team Salvato**.

The following are derived from or contain official DDLC assets:

| Path | What |
| --- | --- |
| `assets/ddlc-stickers/` | character sprites and the dialog box, used by the SDDM theme and hyprlock |
| `assets/just-monika.png` | hyprlock background |
| `assets/monika-talk.txt`, `assets/monika-reentry.txt` | in-game dialogue used by the lock screen |
| `assets/sddm-cursor/` | Sayori's head, plain and glitched, used to build the greeter cursor |
| `nixos/fonts/doki.otf`, `Doki_patched.ttf`, `DokiNerdFontMono-Regular.otf` | the in-game font, and a Nerd-patched variant of it |

Use here follows [Team Salvato's IP guidelines](https://teamsalvato.com/ip-guidelines): this is non-commercial fan content, nothing containing official assets is sold, and no claim of affiliation is made. If you reuse any of it, the same conditions apply to you.

Team Salvato reserves the right to act on copyright or trademark infringement; nothing here grants a licence to their intellectual property.

## Cursors

Two unrelated cursor themes live here, and only one of them is homemade.

`assets/sayori-cursor-v2/` is **Sayori Cursor V2 by sev** ([ko-fi.com/sevverae](https://ko-fi.com/sevverae), [original release](https://ko-fi.com/s/8e05db90c4)) — an animated DDLC-style cursor theme distributed through their ko-fi shop. It is vendored here for convenience only; it is not my work, it carries no licence granting redistribution, and the author's shop is the place to get it. If you want that cursor, download it from sev rather than copying it out of this repo.

`assets/sddm-cursor/` is a two-frame greeter cursor assembled locally with `xcursorgen` from Sayori's head sprite — the build recipe (`nixos/services/desktop/sddm-ddlc/sayori-cursor.nix`) is mine, the sprite it is cut from is Team Salvato's.

## Other bundled fonts

`nixos/fonts/DepartureMono*` — [Departure Mono](https://departuremono.com/), Nerd Fonts patched. Check the upstream licence before redistributing.

## Everything else

Photographs and joke images under `assets/` (`logo.jpg`, `im-king-of-the-world.jpg`, `sayori-v-korobke.jpg`, `shef-os-320-kg.jpg`, `say-sketch2.webp`, `laptop-wallpaper.png`) are decorative and carry no licence claim.
