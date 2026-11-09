{
  config,
  lib,
  pkgs,
  osConfig,
  inputs,
  ...
}:

# The module defaults match the owner's setup: GigaAM-v3 Q4_K_M, Russian speech and the Russian
# interface. Only the cloud model differs from a stock install, and its key comes from sops
{
  config = lib.mkIf config.rokokol.packages.pc {
    programs.molvai = {
      enable = true;
      guiPackage = inputs.molvai.packages.${pkgs.stdenv.hostPlatform.system}.molva-gui;

      settings = {
        llm = {
          enabled = true;
          provider = "openrouter";
          base_url = "https://openrouter.ai/api/v1";
          model = "z-ai/glm-5.3-flash";
          api_key_source = "env";
          api_key_env = "OPENROUTER_API_KEY";
        };

        privacy.cloud_consent = true;

        stt = {
          language = "auto";
          allowed_languages = [
            "ru"
            "en"
          ];
        };

        hotkeys = {
          push_to_talk = "Ctrl+Shift+Enter";
          toggle = "F9";
          command = "Shift+Alt+Enter";
          cancel = "Escape";
          style_next = "Super+Shift+M";
        };

        rules = {
          remove_repeats = false;
          remove_fillers = false;
          spoken_punctuation = false;
          structure = false;
        };
      };
    };

    programs.mcp.servers.molvai = {
      command = lib.getExe config.programs.molvai.package;
      args = [ "mcp" ];
    };

    rokokol.agents.mcpGroups.molvai = "huix";

    systemd.user.services.molva-daemon.Service.EnvironmentFile = [
      osConfig.sops.templates."molvai.env".path
    ];
  };
}
