{
  config,
  lib,
  pkgs,
  huixDir,
  rokokolName,
  ...
}:

let
  workstation = config.rokokol.workstation.enable;
in
{
  home.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    v = "nvim";

    ".." = "cd ..";
    "..." = "cd ../..";

    tp = "trash-put";
  }
  # A host without a desktop has no checkout of huix: it is deployed from one that has
  // lib.optionalAttrs workstation {
    download-music = "yt-dlp -x --audio-format mp3 --audio-quality 0 --embed-metadata --embed-thumbnail -o '%(title)s.%(ext)s'";
    rebuild = "sudo nixos-rebuild switch --flake ${huixDir}";
    rebuilds = "sudo nixos-rebuild switch --flake ${huixDir} --option substituters \"https://mirror.yandex.ru/nixos\"";
    # The station holds no checkout: it is built here and pushed to it over Tailscale SSH
    rebuild-station = "nixos-rebuild switch --flake ${huixDir}#nixos-station --target-host ${rokokolName}@nixos-station --sudo --ask-sudo-password";
  };

  home.packages =
    with pkgs;
    [ trash-cli ]
    ++ lib.optional workstation yt-dlp
    ++ lib.optional (!(config.programs.nixvim.enable or false)) neovim;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = false;
    syntaxHighlighting.enable = true;
    autocd = false;
    defaultKeymap = "viins";

    initContent = ''
      # Selection menu for completion
      zstyle ':completion:*' menu select
      # Colors in the completion list
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

      # Word jumps (Ctrl + arrows)
      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "vi-mode"
      ];
    };

    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.zsh-nix-shell.src;
      }
    ];
  };
}
