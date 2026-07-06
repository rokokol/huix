{
  config,
  pkgs,
  rokokolName,
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        Name = rokokolName;
        Email = "mailofilyusha@gmail.com";
      };
      core.editor = "nvim";
      core.quotepath = "false";
      safe = {
        directory = "${config.custom.home.dataDir}/myWiki";
      };
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
