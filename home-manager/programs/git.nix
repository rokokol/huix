{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings.user.Name = "rokokol";
    settings.user.Email = "mailofilyusha@gmail.com";
    settings.core.editor = "nvim";
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

