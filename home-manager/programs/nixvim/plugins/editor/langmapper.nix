{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = [
      pkgs.vimPlugins.langmapper-nvim
    ];

    extraConfigLua = ''
      local ok, lm = pcall(require, 'langmapper')

      if not ok then
        return
      end

      lm.setup({
        hack_keymap = true,
        map_all_queues = true,
      })

      lm.automapping({ global = true, buffer = true })
    '';
  };
}
