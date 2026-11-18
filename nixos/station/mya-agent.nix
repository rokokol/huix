{
  config,
  lib,
  rokokolName,
  ...
}:

# The Telegram agent edits the archive's folders and the owner's calendars. Syncthing runs as the
# agent's user, so a file the agent makes stays writable to Syncthing, and the agent's edits reach
# every peer. The rest of the backup volume, the snapshots among them, and Syncthing's keys stay
# out of its sight
let
  agent = config.rokokol.mya-agent;
  inherit (config.rokokol.syncthing) archive;
  ownerHome = "/home/${rokokolName}";
in
{
  config = lib.mkMerge [
    # The owner reads and edits everything the agent makes in its home through the agent's
    # group; the hermes sandbox's umask keeps every new file open to that group
    (lib.mkIf agent.enable {
      users.users.${rokokolName}.extraGroups = [ agent.user ];
    })

    # The agent reads and writes the owner's calendars as its own Radicale login
    (lib.mkIf (agent.enable && config.rokokol.radicale.enable) {
      rokokol.radicale.sharedWith = [ agent.user ];
      rokokol.dav-mcp = {
        enable = true;
        inherit (agent) user;
      };
    })

    (lib.mkIf (agent.enable && archive.enable) {
      rokokol.syncthing.archive.editor = agent.user;

      rokokol.mya-agent = {
        # The owner fetches the agent's commits from here over SSH, and syssync takes them
        repositories.huix = "https://github.com/rokokol/huix";
        syncedBy = rokokolName;

        directories = lib.mapAttrs' (
          path: dir: lib.nameValuePair (lib.removePrefix "${ownerHome}/" path) dir
        ) (lib.filterAttrs (path: _: path == "${ownerHome}/myWiki") archive.folders);

        # Syncthing runs as the same user, so /proc/PID/root of Syncthing would show its keys
        # too; the PrivateUsers of the nixpkgs unit shuts that path, and the boot test checks it
        hiddenPaths = [
          archive.mountPoint
          config.services.syncthing.dataDir
        ];
      };

      systemd.services.hermes-agent.after = [ "syncthing.service" ];
    })
  ];
}
