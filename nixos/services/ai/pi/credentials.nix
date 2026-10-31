{
  config,
  lib,
  rokokolName,
  ...
}:
{
  options.rokokol.pi.enable = lib.mkEnableOption "Pi credentials" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.pi.enable {
    sops.secrets."openrouter-pi-key".owner = rokokolName;
    sops.secrets."opencode-go-pi-key".owner = rokokolName;
  };
}
