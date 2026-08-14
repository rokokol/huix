{ ... }:

{
  programs.nixvim.plugins.mini = {
    enable = true;
    modules = {
      icons = { };
    };
    mockDevIcons = true;
  };
}
