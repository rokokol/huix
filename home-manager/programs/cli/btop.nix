{
  base16,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rokokol.btop;
  c = base16.dark;
in
{
  options.rokokol.btop.withCuda = lib.mkEnableOption "btop GPU panel via btop-cuda";

  config = {
    programs.btop = {
      enable = true;
      package = if cfg.withCuda then pkgs.btop-cuda else pkgs.btop;

      settings = {
        color_theme = "ddlc-dark";
        cuda_support = cfg.withCuda;
        rocm_support = false;
        vim_keys = true;
      };
    };

    # base16 holds one shade per hue, so the meters are single-coloured — which is what btop
    # reads an empty "end" as. Only the three real ramps (temperature, CPU, per-process) gradate
    xdg.configFile."btop/themes/ddlc-dark.theme".text = ''
      theme[main_bg]="${c.base00}"
      theme[main_fg]="${c.base05}"
      theme[title]="${c.base06}"
      theme[hi_fg]="${c.base0A}"
      theme[selected_bg]="${c.base02}"
      theme[selected_fg]="${c.base06}"
      theme[inactive_fg]="${c.base03}"
      theme[graph_text]="${c.base04}"
      theme[meter_bg]="${c.base01}"
      theme[proc_misc]="${c.base0B}"

      theme[cpu_box]="${c.base03}"
      theme[mem_box]="${c.base03}"
      theme[net_box]="${c.base03}"
      theme[proc_box]="${c.base03}"
      theme[div_line]="${c.base03}"

      theme[temp_start]="${c.base0B}"
      theme[temp_mid]="${c.base0A}"
      theme[temp_end]="${c.base08}"

      theme[cpu_start]="${c.base0B}"
      theme[cpu_mid]="${c.base0A}"
      theme[cpu_end]="${c.base08}"

      theme[process_start]="${c.base0B}"
      theme[process_mid]="${c.base0A}"
      theme[process_end]="${c.base08}"

      theme[free_start]="${c.base0B}"
      theme[free_mid]=""
      theme[free_end]=""

      theme[cached_start]="${c.base0C}"
      theme[cached_mid]=""
      theme[cached_end]=""

      theme[available_start]="${c.base0A}"
      theme[available_mid]=""
      theme[available_end]=""

      theme[used_start]="${c.base08}"
      theme[used_mid]=""
      theme[used_end]=""

      theme[download_start]="${c.base0D}"
      theme[download_mid]=""
      theme[download_end]=""

      theme[upload_start]="${c.base0E}"
      theme[upload_mid]=""
      theme[upload_end]=""
    '';
  };
}
