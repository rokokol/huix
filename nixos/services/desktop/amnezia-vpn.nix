{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.rokokol.amnezia-vpn.enable = lib.mkEnableOption "the AmneziaVPN client" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.amnezia-vpn.enable {
    programs.amnezia-vpn = {
      enable = true;
      package = pkgs.amnezia-vpn;
    };
  };
}
