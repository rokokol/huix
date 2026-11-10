// The theme button of the documentation site, wired to the vendored DDLC kit. The stored
// choice is applied in <head> before the first paint, so this module only turns the button and
// keeps the choice. Without it every page still reads, in the theme of the system
import { initTheme } from "./vendor/ddlc/ddlc-theme.js"

const button = document.querySelector("[data-theme-toggle]")
const icon = button ? button.querySelector("path") : null

if (button && icon) {
  initTheme({ button, icon, key: "huix-theme" })
}
