{
  config,
  lib,
  inputs,
  ...
}:

# What the agent does on its own, at a time and not on a message. Each hook types a request into
# the live session, so the owner can answer what comes of it there
let
  agent = config.rokokol.mya-agent;
in
{
  options.rokokol.mya-agent.hooks.morning.enable =
    lib.mkEnableOption "the letter the agent writes the owner every morning"
    // {
      default = agent.enable;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
    };

  config = lib.mkIf agent.hooks.morning.enable {
    rokokol.mya-agent.plugins = [
      (builtins.path {
        name = "morning-plugin";
        path = "${inputs.self}/nixos/services/ai/mya-agent/plugins/morning";
      })
    ];

    systemd.services.morning-letter = {
      description = "Ask the Telegram agent for the morning letter";
      after = [ "mya-agent.service" ];
      requisite = [ "mya-agent.service" ];
      serviceConfig = {
        Type = "oneshot";
        # A sentence and not the skill's command, whose name may carry the plugin's prefix
        ExecStart = "${agent.notify} ${lib.escapeShellArg "It is morning: write the owner the morning letter with the morning skill"}";
      };
    };

    systemd.timers.morning-letter = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "09:00";
    };
  };
}
