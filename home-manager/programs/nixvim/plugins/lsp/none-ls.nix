{ lib, pkgs, ... }:

let
  emphasisConfig = pkgs.writeText "markdownlint-emphasis.json" (
    builtins.toJSON {
      default = false;
      MD049.style = "asterisk";
    }
  );
in
{
  programs.nixvim.plugins.none-ls = {
    enable = true;
    sources = {
      formatting.nixfmt.enable = true;
      formatting.black.enable = true;
      formatting.shfmt.enable = true;
      formatting.prettier.enable = true;
      formatting.prettier.disableTsServerFormatter = true;
      diagnostics.deadnix.enable = true;
    };
    # prettier writes emphasis as _text_ and has no option for it, so markdownlint rewrites
    # only that, to *text*. none-ls runs formatters in the order they are registered, and
    # sources.* registers them alphabetically, which would put this pass before prettier;
    # mkAfter at the same mkDefault priority as sources.* puts it last
    settings.sources = lib.mkDefault (
      lib.mkAfter [
        "require('null-ls').builtins.formatting.markdownlint.with({ extra_args = { '--config', '${emphasisConfig}' } })"
      ]
    );
  };
  programs.nixvim.extraPackages = with pkgs; [ markdownlint-cli ];
}
