{
  config,
  lib,
  inputs,
  rokokolName,
  ...
}:

# The Radicale login of one local user, for dav-mcp, the calendar MCP server that the user's
# agents start. The server is registered on the Home Manager side, in
# home-manager/programs/cli/dav-mcp.nix, which reads the password file and the URL from here
let
  cfg = config.rokokol.dav-mcp;
  # The host of this flake that runs Radicale, read from its own configuration
  servers = lib.filterAttrs (
    _: host: host.config.rokokol.radicale.enable
  ) inputs.self.nixosConfigurations;
  server =
    if config.rokokol.radicale.enable then config else (lib.head (lib.attrValues servers)).config;
in
{
  options.rokokol.dav-mcp = {
    enable = lib.mkEnableOption "the Radicale login for the calendar MCP server" // {
      default = config.rokokol.workstation.enable;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = rokokolName;
      description = "Local user whose agents use the calendars, and its login in Radicale";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default =
        if config.rokokol.radicale.enable then
          config.rokokol.radicale.localUrl
        else
          server.rokokol.radicale.url;
      defaultText = lib.literalMD "`rokokol.radicale.localUrl` on the host that runs Radicale, and its `url` elsewhere";
      description = "Root URL of the CalDAV server";
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = config.sops.secrets."radicale-password-${cfg.user}".path;
      defaultText = lib.literalExpression ''config.sops.secrets."radicale-password-''${user}".path'';
      description = "File with the password of `user` in Radicale, readable by that user alone";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rokokol.radicale.enable || servers != { };
        message = "rokokol.dav-mcp needs a host of this flake with rokokol.radicale.enable";
      }
    ];

    # The password lives once, in the secrets of the host that runs Radicale. Its file is
    # encrypted to the owner's key too, which the workstations decrypt with
    sops.secrets."radicale-password-${cfg.user}" = {
      owner = cfg.user;
      sopsFile = server.sops.defaultSopsFile;
    };
  };
}
