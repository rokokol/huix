{
  pkgs,
  rokokolName,
  govnoDir,
  ...
}:

{
  programs.git = {
    enable = true;
    settings.user.Name = rokokolName;
    settings.user.Email = "mailofilyusha@gmail.com";
    settings.core.editor = "nvim";

    extraConfig = {
      safe.directory = "${govnoDir}/myWiki";
    };
  };

  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-dash ];
    settings = {
      editor = "nvim";
      git_protocol = "ssh";
    };
  };
}
