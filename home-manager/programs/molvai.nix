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
          reasoning_effort = "low";
        };

        privacy.cloud_consent = true;
        gui.start_in_tray = true;
        mcp.enabled = true;

        # The text of a phrase is sealed in the journal; the key stays beside it with owner-only
        # permissions, and entries written before this line stay as they are
        journal.encrypt = true;

        stt = {
          # Recognition through OpenRouter: the recording leaves the machine, and the cloud
          # consent above covers it. MAI-Transcribe 2 identifies the language itself and keeps
          # the audio away from providers that store it or train on it
          engine = "remote-openai";
          language = "auto";
          allowed_languages = [
            "ru"
            "en"
          ];
          remote = {
            base_url = "https://openrouter.ai/api/v1";
            model = "microsoft/mai-transcribe-2";
            api_key_source = "env";
            api_key_env = "OPENROUTER_API_KEY";
            zdr = true;
            data_collection = "deny";
          };
        };

        hotkeys = {
          tap_toggles = true;
          push_to_talk = "Ctrl+Shift+Enter";
          toggle = "";
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
