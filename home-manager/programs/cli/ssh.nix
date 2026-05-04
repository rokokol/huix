{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };
    };
  };

  home = {
    sessionVariables = {
      SSH_ASKPASS_REQUIRE = "prefer";
    };
  };
}
