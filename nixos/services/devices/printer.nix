{
  config,
  lib,
  pkgs,
  inputs,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.printer;
  port = 631;
  hosts = lib.attrNames (
    lib.filterAttrs (_: host: host.config.rokokol.printer.enable) inputs.self.nixosConfigurations
  );

  # the filter prefixes its own resource directory to this name, see WORKAROUNDS.md
  epson-l120 = pkgs.epson_201310w.overrideAttrs (old: {
    postFixup = old.postFixup + ''
      substituteInPlace $out/share/cups/model/EPSON_L120.ppd \
        --replace-fail "$out/resource/Epson_201310w.1.data" "Epson_201310w.1.data"
    '';
  });
in
{
  options.rokokol.printer = {
    enable = lib.mkEnableOption "printing (CUPS + gutenprint + Epson L120 driver)";
    skill = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = builtins.path {
        name = "print-skill";
        path = "${inputs.self}/nixos/services/devices/skills/print";
      };
      defaultText = lib.literalMD "The print skill that this module provides";
      description = "Skill for local or remote printing";
    };
    client = {
      enable = lib.mkEnableOption "the print client and skill for this host's agents" // {
        default = cfg.enable;
        defaultText = lib.literalExpression "config.rokokol.printer.enable";
      };
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if cfg.enable || lib.length hosts != 1 then null else lib.head hosts;
        defaultText = lib.literalMD "Local printing when enabled, or the sole printer host in the flake";
        description = "SSH host of the print server, or null for the local CUPS server";
      };
      prepareCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command that prepares the print host, such as a Wake-on-LAN command";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.system-config-printer.enable = true;
      services.printing = {
        enable = true;
        listenAddresses = [ "localhost:${toString port}" ];
        drivers = [
          pkgs.gutenprint
          epson-l120
        ];
      };

      environment.sessionVariables = {
        CUPS_PORT = port;
      };

      users.users.${rokokolName} = {
        extraGroups = [
          "lp"
          "scanner"
        ];
      };
    })
    (lib.mkIf cfg.client.enable {
      assertions = [
        {
          assertion = cfg.enable || cfg.client.host != null;
          message = "A print client without a local CUPS server needs rokokol.printer.client.host";
        }
      ];
    })
  ];
}
