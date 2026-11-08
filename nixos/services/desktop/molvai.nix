{
  config,
  lib,
  rokokolName,
  ...
}:

# The daemon reads its OpenRouter key from the environment, so sops renders it into a file that
# only the owner can read. The secret itself is the same key Pi uses
{
  options.rokokol.molvai.enable = lib.mkEnableOption "the sops environment of MolvAI";

  config = lib.mkIf config.rokokol.molvai.enable {
    sops.secrets."openrouter-pi-key".owner = rokokolName;

    sops.templates."molvai.env" = {
      owner = rokokolName;
      mode = "0400";
      content = "OPENROUTER_API_KEY=${config.sops.placeholder."openrouter-pi-key"}\n";
    };
  };
}
