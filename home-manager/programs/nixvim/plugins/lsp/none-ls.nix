{ lib, pkgs, ... }:

let
  dprintConfig = pkgs.writeText "dprint.json" (
    builtins.toJSON {
      markdown.emphasisKind = "asterisks";
      plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
    }
  );

  # Whether the buffer lives in a project that formats with prettier, as prettier itself
  # decides it: an rc or config file, or a "prettier" key in package.json, in any parent
  hasPrettierConfig = ''
    function(params)
      return vim.fs.find(function(name, path)
        if name:match('^%.prettierrc') or name:match('^prettier%.config%.') then
          return true
        end
        if name == 'package.json' then
          local ok, manifest = pcall(vim.json.decode, table.concat(vim.fn.readfile(path .. '/' .. name), '\n'))
          return ok and type(manifest) == 'table' and manifest.prettier ~= nil
        end
        return false
      end, { upward = true, path = vim.fs.dirname(params.bufname), limit = 1 })[1] ~= nil
    end
  '';
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
      # prettier writes emphasis as _text_ and has no option for it, so Markdown goes to
      # dprint below, unless the project formats with prettier itself
      formatting.prettier.settings.runtime_condition.__raw = ''
        function(params)
          return params.ft ~= 'markdown' or (${hasPrettierConfig})(params)
        end
      '';
      diagnostics.deadnix.enable = true;
    };
    # none-ls ships no dprint source. A project's own dprint config wins over this one;
    # the same mkDefault as sources.* adds it to their list instead of replacing it
    settings.sources = lib.mkDefault [
      ''
        require('null-ls.helpers').make_builtin({
          name = 'dprint',
          method = require('null-ls.methods').internal.FORMATTING,
          filetypes = { 'markdown' },
          generator_opts = {
            command = 'dprint',
            args = function(params)
              local own = vim.fs.find(
                { 'dprint.json', '.dprint.json', 'dprint.jsonc', '.dprint.jsonc' },
                { upward = true, path = vim.fs.dirname(params.bufname), limit = 1 }
              )[1]
              return { 'fmt', '--config', own or '${dprintConfig}', '--stdin', params.bufname }
            end,
            to_stdin = true,
            runtime_condition = function(params)
              return not (${hasPrettierConfig})(params)
            end,
          },
          factory = require('null-ls.helpers').formatter_factory,
        })
      ''
    ];
  };
  programs.nixvim.extraPackages = with pkgs; [ dprint ];
}
