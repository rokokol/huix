{
  config,
  lib,
  huixDir,
  myWikiDir,
  piSharedDir,
  projectsDirs,
  ...
}:
let
  cfg = config.programs.pi-coding-agent;
  writeDirectories = [
    huixDir
    myWikiDir
  ]
  ++ projectsDirs;
  readDirectories = [
    "/nix/store"
    "/run/current-system"
    "/etc/profiles/per-user/${config.home.username}"
    "${config.xdg.configHome}/agents"
    piSharedDir
  ]
  ++ writeDirectories;
  allowPaths =
    tools: directories:
    lib.concatMap (
      path:
      lib.concatMap (tool: [
        "${tool}(${path})"
        "${tool}(${path}/*)"
      ]) tools
    ) directories;
  ownerCommands = [
    "skvpn down*"
    "skvpn up*"
    "skvpn restart*"
    "systemctl stop sing-box*"
    "systemctl restart sing-box*"
    "systemctl stop skvpn*"
    "systemctl restart skvpn*"
    "tailscale down*"
    "nixos-rebuild switch*"
  ];
in
{
  config = lib.mkIf config.rokokol.pi.enable {
    home.sessionVariables.PI_AUTOMODE_SETTINGS_JSON = builtins.toJSON {
      autoMode = {
        allowInsideWorkingDirectory = true;
        classifierModel = "openrouter/z-ai/glm-5.3-flash";
        classifierReasoningLevel = "low";
        soft_deny = [
          "$defaults"
          "Commands that discard uncommitted work, including git checkout, git restore, git reset, git clean, git branch -D, a force push or rm -rf in a working tree, need approval for the specific loss. Run git status first. Prefer stash and trash-put over irreversible operations"
        ];
        hard_deny = [
          "$defaults"
          "Never send a credential, token, private key, password or session cookie to an audience the user does not control. This includes commits, issues, reviews, paste services, chats and third-party APIs, even when quoting a secret in an explanation"
          "Never delete, move or replace ${cfg.configDir}, ${config.xdg.configHome}/agents, ${piSharedDir} or their symlink targets wholesale. Files inside may be read and edited; the directories hold the agent's instructions, settings, credentials and session state"
          "Never delete ordinary files or directories with rm or another command that bypasses the trash. Use trash-put so the deletion can be undone. For a file with a live credential, ask whether to trash it or destroy it irrecoverably before either action"
          "Never take a VPN down on any host, even briefly. This includes skvpn down, up, restart or profile switches, stopping or restarting sing-box or skvpn-guard units, tailscale down and nixos-rebuild switch. Give the owner the exact command instead. The tunnels protect network privacy and host connectivity"
        ];
        log = {
          enabled = true;
          classifierIo = false;
        };
      };
      permissions = {
        allow =
          allowPaths [ "read" "ls" "find" ] readDirectories ++ allowPaths [ "write" "edit" ] writeDirectories;
        deny = lib.concatMap (command: [
          "bash(${command})"
          "bash(sudo ${command})"
        ]) ownerCommands;
      };
    };
  };
}
