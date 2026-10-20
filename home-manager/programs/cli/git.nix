{
  config,
  lib,
  pkgs,
  osConfig,
  huixDir,
  myWikiDir,
  rokokolEmail,
  rokokolName,
  ...
}:

let
  agent = osConfig.rokokol.mya-agent;
in
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
      # Sync loose objects, the index and refs to disk, so a host hang cannot leave them empty
      core.fsync = "added,reference";
      init.defaultBranch = "master";
      # The station's agent owns its clones, and the owner fetches its commits from them
      safe.directory = [
        myWikiDir
      ]
      ++ lib.optionals agent.enable (
        map (dir: "${agent.home}/${dir}") (lib.attrNames agent.repositories)
      );

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

  # Every diff git pages goes through delta, side by side. Its built-in theme asks the terminal
  # whether it is light or dark, so it follows the theme toggle; ddlc-themes has no delta theme
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      side-by-side = true;
      line-numbers = true;
      navigate = true;
      # The long prompt shows how far into the diff the screen is, as nvim's ruler does. less
      # learns the length of piped text only once it has read it all: +Gg reads to the end and
      # comes back to the top, so the percentage is there from the first screen
      pager = "less -RFM +Gg";
    };
  };

  programs.gh = {
    enable = true;
    extensions = with pkgs; [ gh-dash ];
    settings = {
      editor = "nvim";
      git_protocol = "ssh";
    };
  };

  home.packages = with pkgs; [ fh ];
}
