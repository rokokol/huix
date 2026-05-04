{
  pkgs,
  rokokolName,
  govnoDir,
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
      safe = {
        directory = "${govnoDir}/myWiki";
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
