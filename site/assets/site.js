// The theme button of the documentation site, wired to the vendored DDLC kit. The stored choice
// is applied in <head> before the first paint, so this module only turns the button and keeps
// the choice. Without it every page still reads, in the theme of the system
import { initTheme } from "./vendor/ddlc/ddlc-theme.js"

const KEY = "huix-theme"
const button = document.querySelector("[data-theme-toggle]")
const icon = button ? button.querySelector("path") : null

// A `?theme=light` or `?theme=dark` address pins the choice, so a link can show a page in one
// theme; the kit reads the stored value, so the address writes it before the button is built
const asked = new URLSearchParams(location.search).get("theme")
if (asked === "light" || asked === "dark") {
  try {
    localStorage.setItem(KEY, asked)
  } catch {}
}

if (button && icon) {
  initTheme({ button, icon, key: KEY })
}
