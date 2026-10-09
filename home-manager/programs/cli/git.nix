{
  config,
  lib,
  pkgs,
  huixDir,
  myWikiDir,
  rokokolEmail,
  rokokolName,
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        Name = rokokolName;
        Email = rokokolEmail;
      };
      core.editor = "nvim";
      core.quotepath = "false";
      safe = {
        directory = myWikiDir;
      };

      # A token for a forge other than GitHub, such as the station's Forgejo, goes into the
      # GNOME keyring of the desktop. gh keeps GitHub to itself: its URL entries reset this list
      credential.helper = lib.mkIf config.rokokol.workstation.enable (
        lib.getExe' pkgs.gitFull "git-credential-libsecret"
      );
    };

    # The host prefix every huix subject carries is written by a hook rather than by hand, so it
    # survives a commit made in an editor, by a script or by an agent. hooksPath is per-repository
    # on purpose: set globally it would prefix subjects in every other checkout too. The path is
    # the live tree, not the store, because a hook has to be an executable git can call
    includes = [
      {
        condition = "gitdir:${huixDir}/";
        contents.core.hooksPath = "${huixDir}/scripts/git-hooks";
      }
    ];
  };

  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-dash ];
    settings = {
      editor = "nvim";
      git_protocol = "ssh";
    };
  };
}
