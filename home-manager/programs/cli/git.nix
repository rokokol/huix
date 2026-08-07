{
  pkgs,
  myWikiDir,
  rokokolName,
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        Name = rokokolName;
        Email = "git@rokokol.art";
      };
      core.editor = "nvim";
      core.quotepath = "false";
      safe = {
        directory = myWikiDir;
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
