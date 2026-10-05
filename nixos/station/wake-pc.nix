{
  config,
  lib,
  pkgs,
  inputs,
  rokokolName,
  ...
}:

# `wake-pc` sends a magic packet to the PC. The packet goes to the directed broadcast of the LAN
# in network.nix. The kernel's local table binds that address to the wired link, and that table
# is read before any rule of the skvpn TUN. The limited broadcast, 255.255.255.255, belongs to
# no link, so the kernel picks the link for it
let
  # The last address of a CIDR block: each octet gets ones in the host bits that fall into it
  broadcast =
    cidr:
    let
      parts = lib.splitString "/" cidr;
      prefix = lib.toInt (lib.last parts);
      octets = map lib.toInt (lib.splitString "." (lib.head parts));
      hostBits = i: lib.min 8 (lib.max 0 ((i + 1) * 8 - prefix));
      ones = n: lib.foldl' (acc: _: acc * 2 + 1) 0 (lib.range 1 n);
    in
    lib.concatMapStringsSep "." toString (lib.imap0 (i: o: lib.bitOr o (ones (hostBits i))) octets);

  script = builtins.path {
    name = "wake-pc";
    path = "${inputs.self}/scripts/wake-pc.sh";
  };

  wakePc = pkgs.writeShellApplication {
    name = "wake-pc";
    runtimeInputs = with pkgs; [ wakeonlan ];
    runtimeEnv = {
      WAKE_PC_MAC_FILE = config.sops.secrets."pc-mac".path;
      WAKE_PC_BROADCAST = broadcast (lib.head config.systemd.network.networks."10-lan".address);
    };
    text = ''exec ${lib.getExe pkgs.bash} ${script} "$@"'';
  };
in
{
  # The MAC is private, and only the user who runs the command reads it
  sops.secrets."pc-mac".owner = rokokolName;

  users.users.${rokokolName}.packages = [ wakePc ];
}
