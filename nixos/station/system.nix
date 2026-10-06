{
  config,
  pkgs,
  rokokolName,
  ...
}:

{
  networking.hostName = "nixos-station";

  # Accounts come from this configuration alone. The password is the console login, which is
  # the way back in when the tailnet is down; root has none and is reached through sudo.
  # sops-nix decrypts a neededForUsers secret before the users are created
  users.mutableUsers = false;
  users.users.${rokokolName} = {
    description = rokokolName;
    hashedPasswordFile = config.sops.secrets."rokokol-password-hash".path;
  };
  sops.secrets."rokokol-password-hash".neededForUsers = true;

  # A server stays up: logind refuses every sleep state, whoever asks. The power key keeps the
  # stock poweroff, as only nixos/desktop/logind.nix changes it
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # The owner connects from kitty, which sets TERM=xterm-kitty over SSH
  environment.systemPackages = with pkgs; [ kitty.terminfo ];
}
