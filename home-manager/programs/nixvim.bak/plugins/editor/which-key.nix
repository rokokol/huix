{ ... }:

{
  programs.nixvim.plugins.which-key = {
    enable = true;
    settings = {
      win.border = "rounded";
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
