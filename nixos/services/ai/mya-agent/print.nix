{
  config,
  lib,
  inputs,
  ...
}:

# The agent prints when the owner asks. The printer stands at the PC, where the agent logs in as
# its guest user
let
  agent = config.rokokol.mya-agent;
in
{
  options.rokokol.mya-agent.print.enable =
    lib.mkEnableOption "the skill that prints on the PC's printer"
    // {
      default = agent.enable;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
    };

  config = lib.mkIf agent.print.enable {
    rokokol.mya-agent.plugins = [
      (builtins.path {
        name = "print-plugin";
        path = "${inputs.self}/nixos/services/ai/mya-agent/plugins/print";
      })
    ];
  };
}
