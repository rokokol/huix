{ ... }:

{
  # By default logind suspends on lid close, IGNORING inhibitor locks
  # (LidSwitchIgnoreInhibited=yes). With no the handle-lid-switch lock starts
  # working — this is what the "lid blanks the screen instead of suspending"
  # mode relies on (scripts/lid-mode.sh, bind SUPER+SHIFT+A, see
  # hyprland/services/lid-mode.nix). The lid behavior itself stays at the
  # default (suspend), so outside a Hyprland session — on the login screen, in a
  # tty — the laptop suspends as usual
  services.logind.settings.Login.LidSwitchIgnoreInhibited = "no";
}
