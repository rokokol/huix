{ rokokolName, ... }:

{
  networking.hostName = "nixos-pc";
  users.users.${rokokolName}.description = "sigma pro";
}
