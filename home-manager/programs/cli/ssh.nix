{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
    };
  };

  home = {
    sessionVariables = {
      SSH_ASKPASS_REQUIRE = "prefer";
    };
  };
}
