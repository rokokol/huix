_:

{
  programs.nixvim.plugins.which-key = {
    enable = true;
    settings = {
      win.border = "rounded";
      # langmapper's Cyrillic twins stay bound but out of the popup: every key is read by its
      # Latin place, and a second alphabet beside it only gets in the way
      filter.__raw = ''function(mapping) return not (mapping.lhs or ""):find("[\128-\255]") end'';
      spec = [
        {
          __unkeyed = "<leader>f";
          group = "Find";
        }
        {
          __unkeyed = "<leader>g";
          group = "Git";
        }
        {
          __unkeyed = "<leader>l";
          group = "LSP";
        }
        {
          __unkeyed = "<leader>t";
          group = "Terminals";
        }
        {
          __unkeyed = "<leader>u";
          group = "UI";
        }
      ];
    };
  };
}
