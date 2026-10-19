{
  config,
  lib,
  inputs,
  ...
}:

# The agent works with the owner's calendars through the dav MCP server of its own user, which
# nixos/services/tools/dav-mcp.nix gives a login. The skill says which calendar is whose
let
  agent = config.rokokol.mya-agent;
  login = config.rokokol.dav-mcp;
in
{
  options.rokokol.mya-agent.calendar.enable =
    lib.mkEnableOption "the skill that works with the owner's calendars"
    // {
      default = agent.enable && login.enable && login.user == agent.user;
      defaultText = lib.literalMD "on when the agent's user has the calendar login";
    };

  config = lib.mkIf agent.calendar.enable {
    rokokol.mya-agent.plugins = [
      (builtins.path {
        name = "calendar-plugin";
        path = "${inputs.self}/nixos/services/ai/mya-agent/plugins/calendar";
      })
    ];
  };
}
