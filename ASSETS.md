# Assets and third-party content

`LICENSE` (MIT) covers the **code** in this repository — Nix modules, shell scripts, QML, CSS and configuration. It does **not** cover the artwork, fonts and text listed here, which belong to their respective owners and are included as fan content

## Doki Doki Literature Club

Doki Doki Literature Club and Doki Doki Literature Club Plus are the property of [Team Salvato](https://teamsalvato.com/). This project is **unaffiliated with and not endorsed by Team Salvato**

The greeter sprites and the greeter cursor left with the theme — they live in [rokokol/ddlc-sddm-theme](https://github.com/rokokol/ddlc-sddm-theme) now, under the same conditions. The lock screen's background, its dialog box and every line it types went the same way, into [rokokol/ddlc-hyprlock](https://github.com/rokokol/ddlc-hyprlock)

Use here follows [Team Salvato's IP guidelines](https://teamsalvato.com/ip-guidelines): this is non-commercial fan content, nothing containing official assets is sold, and no claim of affiliation is made. If you reuse any of it, the same conditions apply to you

Team Salvato reserves the right to act on copyright or trademark infringement; nothing here grants a licence to their intellectual property

## Cursors

`assets/sayori-cursor-v2/` is **Sayori Cursor V2 by sev** ([ko-fi.com/sevverae](https://ko-fi.com/sevverae), [original release](https://ko-fi.com/s/8e05db90c4)) — an animated DDLC-style cursor theme distributed through their ko-fi shop. It is vendored here for convenience only; it is not my work, it carries no licence granting redistribution, and the author's shop is the place to get it. If you want that cursor, download it from sev rather than copying it out of this repo

It is not my artwork and it is not the greeter cursor — that one is cut from the game's own sprites and lives in [rokokol/ddlc-sddm-theme](https://github.com/rokokol/ddlc-sddm-theme)

## Other bundled fonts

`nixos/fonts/departure-mono-*` — [Departure Mono](https://departuremono.com/), Nerd Fonts patched. Check the upstream licence before redistributing

`nixos/fonts/doki.otf`, `doki-patched.ttf`, `doki-nerd-font-mono-regular.otf` — Doki, a font by 538Fonts from 2015, and variants of it patched here. It is free for personal use only and is not part of the game

## DeepWiki badge

`assets/ask-deepwiki.svg` is DeepWiki's own "Ask DeepWiki" badge, copied once from `https://deepwiki.com/badge.svg` and served from this repository because GitHub's camo proxy can no longer fetch that URL: deepwiki.com now answers a non-browser request with a Vercel bot challenge, so the badge rendered as a broken image. It is their artwork, it links to their page, and nothing is claimed about it

## Mya

`assets/mya-logo.png`, the picture of Mya in the agent's README, is my own drawing

## The documentation site

`site/assets/vendor/ddlc/` is the DDLC web kit from [ddlc-themes](https://github.com/rokokol/ddlc-themes), vendored unchanged at commit `b7ee74d`: `ddlc-tokens.css`, `ddlc-ui.css`, `ddlc-report.css`, `ddlc-theme.js` and `ddlc-cloud.js`, MIT as the repository that generates them. The colours in them are Team Salvato's, measured off [ddlc.moe](https://ddlc.moe/) by [ddlc-palette](https://github.com/rokokol/ddlc-palette); the mapping of colour to role is the work of ddlc-themes

The built site also takes Departure Mono and Mya Nunito from the locked `ddlc-themes` input. Their licence files are installed beside the fonts under `assets/vendor/ddlc/`

`ASSETS.md` and the site itself are mine. The GitHub mark at `site/assets/github.svg` is shared by the landing page and the documentation. It takes its colour from the text role, so it follows the theme. The mark in the tab is `assets/can-you-read-this-with-me.jpg`, the same file the repository already holds

## Everything else

The decorative images under `assets/` (`logo.jpg`, `can-you-read-this-with-me.jpg`, `im-king-of-the-world.jpg`, `sayori-v-korobke.jpg`, `shef-os-320-kg.jpg`, `say-sketch2.webp`, `laptop-wallpaper.png`) are pictures collected off the internet. Several are drawings whose authors I do not know, and I claim no ownership of any of them — they are here as decoration for the READMEs, as a wallpaper and as the mark in the tab of the documentation site

If you drew one of these and want credit or want it taken down, open an issue and it will be done
