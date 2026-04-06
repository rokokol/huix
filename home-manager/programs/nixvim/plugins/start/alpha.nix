{ ... }:

{
  programs.nixvim.plugins.alpha = {

    enable = true;

    settings.layout = [
      # 1. Logo (ASCII Art)
      {
        type = "padding";
        val = 4;
      }
      {
        type = "text";
        val = {
          __raw = ''
            function()
              local logos = {
                {
                  "⠄⠄⠠⠄⢑⢽⣧⡀⠄⠅⠘⡽⣿⣄⡀⠄⠐⠐⠄⢀⠂⢀⠂⢀⠐⢀⢀⠄⢀⠄⡀⠁⠂⠈⡢⡀⠄⢁⠂⡈⡀⢀⠄⢁⢁⠄⢁⠄⠁⡈",
                  "⠂⠠⠄⡀⠠⣺⣿⣷⡄⠄⠄⠐⠿⣿⣷⠔⠐⢀⠐⠄⢁⠄⢐⠄⢈⠐⠰⠂⠄⡁⢀⠂⠄⠄⠰⠲⠃⠄⠁⠁⠈⠐⠂⠄⠂⠐⢈⠐⠂⠐",
                  "⡁⠐⠄⠄⠄⢀⣩⣆⣴⣆⠄⠠⠄⣶⣶⣾⣧⣄⠄⠄⠡⠂⠠⢁⢈⠐⡂⠈⠈⠆⡐⡂⢐⢂⢀⠑⠺⣿⣦⣀⠢⠄⠐⡀⡀⠄⠄⠈⠈⠠",
                  "⠄⠄⢀⠄⠄⠸⣿⣿⣿⣿⣷⣦⡀⠘⢿⣿⣿⣿⣷⣆⡀⠐⠄⠠⡐⡐⠅⠰⠰⠄⡀⠈⠐⠁⠨⢐⠂⡈⠙⠿⢷⣤⡄⠂⠄⠄⠡⡀⠂⠠",
                  "⠱⢤⣐⠠⠂⡀⢹⣿⣿⣿⣿⣿⣿⣶⡌⡻⣿⣿⣿⣿⣿⣶⣄⠄⠈⡂⠄⠌⠄⣀⣁⢁⡀⡀⢀⢀⣀⢠⣈⣀⣄⣍⣹⣷⣴⣀⡁⠐⢃⢄",
                  "⣄⣹⣿⣷⣦⠤⠄⠉⠻⢟⣻⣿⢿⣿⣷⣷⣷⣿⣿⣿⣿⣿⣿⣆⢱⣦⣬⣂⣁⡈⡙⠿⣿⣯⣏⣿⣷⣿⣿⡿⣟⡿⢟⠻⠛⢿⣿⣾⣶⣮",
                  "⢿⠟⠁⠄⠄⠄⠄⠄⠄⠄⠄⠄⠙⠹⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡿⠛⠉⠄⠄⠄⠄⠄⠄⠄⠄⠄⠙⠿",
                  "⠄⠄⠄⠄⠄⠄⠄⠄⠄⢀⠄⠄⢠⡀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⠂⣀⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄",
                  "⣀⠄⣠⡄⠄⠄⠄⠄⠄⠄⠄⢀⣸⣽⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣾⣯⣿⡿⢀⠄⠄⠄⠄⠄⠄⠁⠄⠄",
                  "⣾⣦⠙⠋⠃⠄⠄⠄⠄⠄⠈⠄⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠄⠄⠄⠄⠄⠄⠄⠄⠄⠐⣶",
                  "⣿⣿⣆⠄⠄⢀⡪⢧⢌⡦⠄⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠄⠠⢯⡲⣖⡣⠄⠄⣼⣿",
                  "⣿⣿⣿⣦⣠⣄⣉⣈⣬⣌⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⣌⣅⣘⣌⣊⣠⣴⣿⣿",
                  "⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣷⣿⣟⣯⡯⣿",
                  "⡹⣿⣻⣽⣟⣟⣿⡿⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⡿⣟⣫⡽⣽⣟⣹⢿⣟",
                  "⢽⡷⣻⡾⣽⡿⣯⡿⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣻⣻⣗⣽⣟⣺⣟⢽⢷⢽⣏⡯",
                  "⢷⢽⡟⡾⣻⣹⣞⣽⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⣷⣻⣾⣟⣗⣻⣗⣳⡾⣺⢶⢽",
                  "⢽⡾⣝⣗⢽⡽⣽⡿⣹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣻⣾⣞⣯⣹⣗⡽⣽",
                  "⠪⣯⣫⣻⢾⣿⡿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣽⣷⣻⣯⣿⢾⣽⡯",
                  "⠄⠹⣿⣾⣿⣽⣿⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣿⣽⣷⠃",
                  "⠄⠄⢹⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠄",
                  "⠄⠄⠄⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠄⠄",
                  "⠄⠄⠄⠄⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣬⣭⣍⣩⣭⣥⣤⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠄⠄⠄",
                  "⠄⠄⠄⠄⠄⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠄⠄⠄⠄",
                  "⠄⠄⠄⠄⠄⠄⠘⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠄⠄⠄⠄⠄⠄",
                  "⠄⠄⠄⠄⠄⠄⠄⠄⠈⠛⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠁⠄⠄⠄⠄⠄⠄⠄",
                },
                {
                  "⠀⠀⠀⠀⠀⠀⠀⠀⡁⡊⠅⡂⡂⠄⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢀⢀⢀⠀⠀⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⢀⡐⡤⡱⡰⡲⡳⡢⣕⢤⢀⠀⠂⠈⠀⠀⠀⠀⠀⠀⠨⠀⠀",
                  "⠀⠀⠀⠀⡀⡰⡸⡰⡱⡱⡙⡜⡜⢜⢜⢜⢗⢽⡹⡤⣄⢀⠀⠀⠀⠀⠀⠨⠀⠀",
                  "⠀⠀⠠⡪⢪⢊⢎⢜⢌⢎⢎⢎⢎⢎⢎⢪⢪⢱⢝⡞⡮⣣⡂⠀⠀⠀⠀⡈⠀⠀",
                  "⠀⡐⡕⡕⡕⢵⢱⠱⡱⡑⡕⡜⡔⡕⡕⡕⡕⢕⢕⢽⡹⡪⡮⡀⠀⠀⢠⡲⠀⠀",
                  "⠐⡀⢌⠌⢊⠺⠸⠸⠸⡘⡘⢌⠪⡨⡊⣒⡕⢕⢅⢇⢯⡫⡮⣳⠀⠠⡣⡯⣃⠀",
                  "⣂⠀⡆⢁⠢⢨⠌⡌⡂⡆⡪⣡⡣⡪⡪⡒⡼⡸⡸⡨⡳⣝⣝⢮⡊⠌⢌⠙⢮⡀",
                  "⠕⡕⡕⡕⡕⡅⠘⡜⡜⡜⡜⡔⣊⠪⡪⡪⢪⢱⢱⠱⡑⣧⢳⡳⡣⢑⠠⢑⢎⡇",
                  "⠇⡇⡕⡜⡌⡇⣀⠀⠱⣘⠜⡜⠬⡅⣔⠓⠃⠧⡇⡇⡇⣯⡳⡽⡐⠄⢅⢗⣝⡇",
                  "⢨⢪⢪⠪⡪⣣⡤⣤⠄⠈⠀⠀⠀⠀⠀⣖⠝⣖⠢⡣⡣⡇⡯⣞⢦⢑⢮⡳⣕⠃",
                  "⠀⠪⡆⡇⡇⣃⠣⡁⡃⠀⠀⠀⠀⠀⠀⠐⠄⠂⠨⡪⢌⡗⠃⢯⡳⣝⢵⢝⠾⠀",
                  "⠀⠀⠫⠪⢚⣎⠂⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠐⡨⡪⡪⠁⣘⢗⣝⢮⡳⣝⠃⠀",
                  "⠀⠀⠀⠀⢀⢮⢦⠀⠀⠀⠈⠊⠃⠀⠀⢀⠀⢱⢱⢑⠅⣔⢗⣝⢮⡳⣝⠂⠀⠀",
                  "⠀⠀⠀⠀⡼⡥⡉⠃⡁⠀⡄⣤⡠⠤⢍⠀⠠⡣⡣⠍⣜⢮⡳⣓⣗⢽⠂⠀⠀⠀",
                  "⠀⠀⠀⢸⢮⡫⡆⠱⡰⢸⡘⣜⠭⡑⠑⡔⡪⢎⢆⢰⡳⡳⣝⢮⢮⣋⠀⠀⠀⣼",
                  "⠀⠀⠀⠀⠙⠙⠑⠀⠈⠢⡱⢨⠪⣸⡀⠈⠪⠊⠀⠜⡮⣫⢮⡳⡳⣕⣖⢤⡺⡚",
                  "⠀⠀⠀⠀⠀⠀⠀⢀⡴⣷⣸⡺⣌⡶⡳⡄⠀⠀⠁⠁⠙⢎⡷⢝⣝⢮⢮⠳⠉⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⠀⠽⠵⡯⠺⣝⡮⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣖⡖⣶⣾⡁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⡾⡅⠈⠙⠿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
                  "⠀⠀⠀⠀⠀⠀⠀⢠⡄⢠⡄⠀⢠⡄⢠⡤⢤⠠⠤⡤⠤⠀⠀⠀⠀⠀⠀⠀⠀ ",
                  "⠀⠀⠀⠀⠀⠀⠀⢸⡇⢸⡇⠀⢸⡇⠙⠷⣤⠀⠀⡇⠀ ⠀⠀      ",
                  "⠀⠀⠀⠀⠀ ⠀⠞⠃⠈⠓⠶⠛⠀⠓⠶⠛⠀ ⠃⠀⠀        ",
                  "⢠⣤⠀⠀⣠⣤⠀⣠⡤⢤⣄⠀⣤⣄⠀⣤⠀⣤⠀⣤⠀⣠⠄⠀⣠⣄    ",
                  "⢸⡟⣧⢰⠇⣿⠠⣟⠀⠀⣿⠄⣿⠹⣆⣿⠀⣿⠀⣿⢾⡅⠀⢰⣏⣹⡆⠀  ",
                  "⠘⠃⠘⠋⠀⠛⠀⠙⠲⠖⠋⠀⠛⠀⠘⠛⠀⠛⠀⠛⠀⠛⠂⠛⠀⠀⠛⠀⠀⠀",
                },
              }
              
              math.randomseed(os.time())
              return logos[math.random(#logos)]
            end
          '';
        };
        opts = {
          position = "center";
          hl = "Special";
        };
      }

      {
        type = "padding";
        val = 2;
      }

      # 2. Menu Buttons
      {
        type = "group";
        val = [
          # Button: Restore Session
          {
            type = "button";
            val = "  Restore Session";
            on_press = {
              __raw = "function() require('persistence').load().load({ last = true }) end";
            };
            opts = {
              position = "center";
              shortcut = "s";
              cursor = 3;
              width = 40;
              align_shortcut = "right";
              hl = "Identifier";
              hl_shortcut = "WarningMsg";
              # Keymap to prevent buffer modification error
              keymap = [
                "n"
                "s"
                "<cmd>lua require('persistence').load()<CR>"
                {
                  noremap = true;
                  silent = true;
                  nowait = true;
                }
              ];
            };
          }
          # Button: Recent Files
          {
            type = "button";
            val = "  Recent Files";
            on_press = {
              __raw = "function() vim.cmd('Telescope oldfiles') end";
            };
            opts = {
              position = "center";
              shortcut = "r";
              cursor = 3;
              width = 40;
              align_shortcut = "right";
              hl = "String";
              hl_shortcut = "WarningMsg";
              keymap = [
                "n"
                "r"
                "<cmd>Telescope oldfiles<CR>"
                {
                  noremap = true;
                  silent = true;
                  nowait = true;
                }
              ];
            };
          }
          # Button: Quit
          {
            type = "button";
            val = "  Quit";
            on_press = {
              __raw = "function() vim.cmd('qa') end";
            };
            opts = {
              position = "center";
              shortcut = "q";
              cursor = 3;
              width = 40;
              align_shortcut = "right";
              hl = "Number";
              hl_shortcut = "WarningMsg";
              keymap = [
                "n"
                "q"
                "<cmd>qa<CR>"
                {
                  noremap = true;
                  silent = true;
                  nowait = true;
                }
              ];
            };
          }
        ];
      }

      # 3. Footer (Stats)
      {
        type = "padding";
        val = 2;
      }
      # {
      #   type = "text";
      #   val = {
      #     __raw = ''
      #       function()
      #         local v = vim.version()
      #         local datetime = os.date(" %H:%M   %d.%m.%Y")
      #         local plugins_count = vim.fn.len(vim.api.nvim_list_runtime_paths())
      #         return {
      #           datetime,
      #           " v" .. v.major .. "." .. v.minor .. "." .. v.patch .. "  ●  󰚥 " .. plugins_count .. " plugins"
      #         }
      #       end
      #     '';
      #   };
      #   opts = {
      #     position = "center";
      #     hl = "Comment";
      #   };
      # }
      {
        type = "text";
        val = {
          __raw = ''
            function()
              local fortune = require("alpha.fortune")()
              
              if type(fortune) == "table" and #fortune > 0 then
                fortune[1] = "" .. fortune[1]
                fortune[#fortune] = fortune[#fortune] .. ""
              end
              return fortune
            end
          '';
        };
        opts = {
          hl = "Comment";
          position = "center";
        };
      }
    ];
  };
}
