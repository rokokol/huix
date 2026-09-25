{ pkgs, base16, ... }:

# Two flavors built from the palette, so yazi looks like ddlc.nvim: each colour plays the role
# it has in that theme's core groups (CursorLine, Search, FloatBorder, FloatTitle, PmenuSel).
# Nothing paints the ground, so the terminal's background shows, as it does under nvim. yazi
# picks the flavor from the terminal's own colour scheme and swaps it live when that changes
let
  toml = pkgs.formats.toml { };

  flavor = c: {
    mgr = {
      cwd.fg = c.base0E;
      find_keyword = {
        fg = c.base0A;
        bold = true;
        underline = true;
      };
      find_position = {
        fg = c.base09;
        bold = true;
      };
      symlink_target = {
        fg = c.base0C;
        italic = true;
      };
      marker_copied = {
        fg = c.base0B;
        bg = c.base0B;
      };
      marker_cut = {
        fg = c.base08;
        bg = c.base08;
      };
      marker_marked = {
        fg = c.base0C;
        bg = c.base0C;
      };
      marker_selected = {
        fg = c.base0A;
        bg = c.base0A;
      };
      count_copied = {
        fg = c.base00;
        bg = c.base0B;
      };
      count_cut = {
        fg = c.base00;
        bg = c.base08;
      };
      count_selected = {
        fg = c.base00;
        bg = c.base0A;
      };
      border_style.fg = c.base02;
    };

    indicator = {
      parent.bg = c.base01;
      current = {
        bg = c.base01;
        bold = true;
      };
      preview.underline = true;
    };

    tabs = {
      active = {
        fg = c.base0B;
        bg = c.base01;
        bold = true;
      };
      inactive = {
        fg = c.base03;
        bg = c.base01;
      };
    };

    mode = {
      normal_main = {
        fg = c.base00;
        bg = c.base0D;
        bold = true;
      };
      normal_alt = {
        fg = c.base0D;
        bg = c.base01;
      };
      select_main = {
        fg = c.base00;
        bg = c.base0E;
        bold = true;
      };
      select_alt = {
        fg = c.base0E;
        bg = c.base01;
      };
      unset_main = {
        fg = c.base00;
        bg = c.base08;
        bold = true;
      };
      unset_alt = {
        fg = c.base08;
        bg = c.base01;
      };
    };

    status = {
      perm_sep.fg = c.base03;
      perm_type.fg = c.base0D;
      perm_read.fg = c.base0A;
      perm_write.fg = c.base08;
      perm_exec.fg = c.base0B;
      progress_label = {
        fg = c.base05;
        bold = true;
      };
      progress_normal = {
        fg = c.base0B;
        bg = c.base01;
      };
      progress_error = {
        fg = c.base08;
        bg = c.base01;
      };
    };

    which = {
      border.fg = c.base03;
      cand.fg = c.base0D;
      rest.fg = c.base03;
      desc.fg = c.base05;
      separator_style.fg = c.base03;
    };

    confirm = {
      border.fg = c.base03;
      title.fg = c.base0E;
      btn_yes = {
        fg = c.base01;
        bg = c.base05;
      };
    };

    spot = {
      border.fg = c.base03;
      title.fg = c.base0E;
      tbl_col.fg = c.base0D;
      tbl_cell = {
        fg = c.base0A;
        reversed = true;
      };
    };

    notify = {
      title_info.fg = c.base0B;
      title_warn.fg = c.base0A;
      title_error.fg = c.base08;
    };

    pick = {
      border.fg = c.base03;
      active = {
        fg = c.base0E;
        bold = true;
      };
    };

    input = {
      border.fg = c.base03;
      title.fg = c.base0E;
      selected.bg = c.base02;
    };

    cmp = {
      border.fg = c.base03;
      active = {
        fg = c.base01;
        bg = c.base05;
      };
    };

    tasks = {
      border.fg = c.base03;
      title.fg = c.base0E;
      hovered = {
        fg = c.base0E;
        bold = true;
      };
    };

    help = {
      border.fg = c.base03;
      chord.fg = c.base0D;
      hovered = {
        fg = c.base01;
        bg = c.base05;
        bold = true;
      };
    };

    filetype.rules = [
      {
        mime = "**/image/*";
        fg = c.base0A;
      }
      {
        mime = "**/{audio,video}/*";
        fg = c.base0E;
      }
      {
        mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
        fg = c.base08;
      }
      {
        mime = "**/application/{pdf,doc,rtf}";
        fg = c.base0C;
      }
      {
        mime = "vfs/{absent,stale}";
        fg = c.base03;
      }
      {
        url = "*";
        is = "orphan";
        bg = c.base08;
      }
      {
        url = "*";
        is = "exec";
        fg = c.base0B;
      }
      {
        url = "*";
        is = "dummy";
        bg = c.base08;
      }
      {
        url = "*/";
        is = "dummy";
        bg = c.base08;
      }
      {
        url = "*/";
        fg = c.base0D;
      }
    ];
  };

  mkFlavor =
    variant:
    pkgs.linkFarm "yazi-flavor-ddlc-${variant}" {
      "flavor.toml" = toml.generate "flavor.toml" (flavor base16.${variant});
    };
in
{
  programs.yazi = {
    flavors = {
      ddlc-dark = mkFlavor "dark";
      ddlc-light = mkFlavor "light";
    };
    theme.flavor = {
      dark = "ddlc-dark";
      light = "ddlc-light";
    };
  };
}
