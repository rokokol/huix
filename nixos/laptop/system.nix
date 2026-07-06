{ rokokolName, ... }:

{
  networking.hostName = "nixos-laptop";
  users.users.${rokokolName}.description = rokokolName;
}
