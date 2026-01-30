{ pkgs, ... }:

{
  home.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    v = "nvim";
    conf = "cd ~/huix/home-manager/ && nvim home.nix";

    ".." = "cd ..";
    "..." = "cd ../..";

    # cp = "cp -iv";
    # mv = "mv -iv";
    # rm = "rm -iv";
    tp = "trash-put";
    rebuild = "sudo nixos-rebuild switch --flake ~/huix";
  };

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

    initContent = ''
      # Enable selection menu
      zstyle ':completion:*' menu select
      # Add colors to the list
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}" 

      # Word jumping (Ctrl + Arrows)
      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
    '';

    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.8.0";
          sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
        };
      }
    ];
  };
}

