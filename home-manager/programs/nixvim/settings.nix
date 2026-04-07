{ ... }:

{
  programs.nixvim = {
    # --- Globals ---
    diagnostics = {
      underline = false;
      virtual_text = false;
    };
    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };
    # --- Options ---
    opts = {
      confirm = true;
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      termguicolors = true;
      cursorline = true;
      scrolloff = 8;
      timeoutlen = 300;

      pumheight = 10;
      pumblend = 0;
      winblend = 0;

      undofile = true;
      undodir = {
        __raw = "vim.fn.stdpath('data') .. '/undo'";
      };
      undoreload = 1000;
      undolevels = 1000;

      clipboard = "unnamedplus";
      # Russian layout support for commands
      langmap = "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz";
      updatetime = 250;
    };

    # --- Appearance ---
    colorschemes.gruvbox = {
      enable = true;
      settings = {
        transparent_mode = true;
        overrides = {
          NormalFloat.bg = "none";
          FloatBorder.bg = "none";
          Pmenu.bg = "none";
          TelescopeNormal.bg = "none";
          TelescopeBorder.bg = "none";
          WhichKeyFloat.bg = "none";
        };
      };
    };

    # --- Lua Config ---
    extraConfigLua = ''
      local disabled_built_ins = {
        "netrw", "netrwPlugin", "netrwSettings", "netrwFileHandlers",
        "gzip", "zip", "zipPlugin", "tar", "tarPlugin", "tohtml"
      }
      for _, plugin in ipairs(disabled_built_ins) do
        vim.g["loaded_" .. plugin] = 1
      end

      _G.HuixTelescopeFilePreviewer = _G.HuixTelescopeFilePreviewer or function()
        local previewers = require("telescope.previewers")
        local from_entry = require("telescope.from_entry")

        local mime_cache = {}

        local function get_mime_type(filepath)
          if filepath == nil or filepath == "" then
            return nil
          end

          if mime_cache[filepath] ~= nil then
            return mime_cache[filepath]
          end

          local mime = vim.fn.system({ "file", "--mime-type", "-b", "--", filepath })

          if vim.v.shell_error ~= 0 then
            mime_cache[filepath] = false
            return nil
          end

          mime = vim.trim(mime)
          mime_cache[filepath] = mime ~= "" and mime or false

          return mime_cache[filepath] or nil
        end

        local function get_term_command(entry, status)
          local filepath = from_entry.path(entry, true, false)

          if filepath == nil or filepath == "" then
            return nil
          end

          filepath = vim.fn.expand(filepath)

          local mime = get_mime_type(filepath)
          local is_image = mime and mime:match("^image/") ~= nil
          local is_video = mime and mime:match("^video/") ~= nil
          local is_audio = mime and mime:match("^audio/") ~= nil
          local is_pdf = mime == "application/pdf"

          local width = 80
          local height = 40
          local preview_winid = status.layout.preview and status.layout.preview.winid

          if preview_winid and vim.api.nvim_win_is_valid(preview_winid) then
            width = math.max(vim.api.nvim_win_get_width(preview_winid) - 2, 20)
            height = math.max(vim.api.nvim_win_get_height(preview_winid) - 2, 10)
          end

          if is_image then
            return {
              "bash",
              "-lc",
              [[
                tmp="$(mktemp -u)"
                magick "$1[0]" -auto-orient "$tmp.png" >/dev/null 2>&1 && \
                  chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                rm -f "$tmp.png"
              ]],
              "telescope-preview",
              filepath,
              tostring(width),
              tostring(height),
            }
          end

          if is_pdf then
            return {
              "bash",
              "-lc",
              [[
                tmp="$(mktemp -u)"
                pdftoppm -png -singlefile -- "$1" "$tmp" >/dev/null 2>&1 && \
                  chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                rm -f "$tmp.png"
              ]],
              "telescope-preview",
              filepath,
              tostring(width),
              tostring(height),
            }
          end

          if is_video then
            return {
              "bash",
              "-lc",
              [[
                tmp="$(mktemp -u)"
                ffmpegthumbnailer -i "$1" -o "$tmp.png" -s 0 -q 8 >/dev/null 2>&1 && \
                  chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                rm -f "$tmp.png"
              ]],
              "telescope-preview",
              filepath,
              tostring(width),
              tostring(height),
            }
          end

          if is_audio then
            return {
              "bash",
              "-lc",
              [[
                tmp="$(mktemp -u)"
                ffmpeg -v error -i "$1" \
                  -filter_complex "showwavespic=s=$2x$3:colors=white" \
                  -frames:v 1 "$tmp.png" >/dev/null 2>&1 && \
                  chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                status=$?
                if [ "$status" -ne 0 ]; then
                  printf 'Audio file\n\n'
                  printf 'Name: %s\n' "$(basename "$1")"
                  printf 'Type: %s\n' "$4"
                  printf '\nWaveform preview failed.\n'
                fi
                rm -f "$tmp.png"
              ]],
              "telescope-preview",
              filepath,
              tostring(width),
              tostring(height),
              mime,
            }
          end

          return nil
        end

        return previewers.new({
          setup = function()
            return {
              active = nil,
              buffer = previewers.vim_buffer_cat.new({}),
              term = previewers.new_termopen_previewer({
                get_command = function(entry, status)
                  return get_term_command(entry, status)
                end,
              }),
            }
          end,
          preview_fn = function(self, entry, status)
            local filepath = from_entry.path(entry, true, false)
            local delegate = self.state.buffer

            if filepath and filepath ~= "" and get_term_command(entry, status) ~= nil then
              delegate = self.state.term
            end

            self.state.active = delegate
            return delegate:preview(entry, status)
          end,
          teardown = function(self)
            if self.state then
              self.state.buffer:teardown()
              self.state.term:teardown()
            end
          end,
          send_input = function(self, input)
            if self.state and self.state.active then
              self.state.active:send_input(input)
            end
          end,
          scroll_fn = function(self, direction)
            if self.state and self.state.active then
              self.state.active:scroll_fn(direction)
            end
          end,
          scroll_horizontal_fn = function(self, direction)
            if self.state and self.state.active then
              self.state.active:scroll_horizontal_fn(direction)
            end
          end,
        })
      end

      _G.HuixTelescopeFindFiles = _G.HuixTelescopeFindFiles or function(opts)
        local builtin = require("telescope.builtin")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        opts = opts or {}

        local hidden = opts.hidden == true
        local picker_opts = vim.tbl_extend("force", {
          hidden = hidden,
          previewer = _G.HuixTelescopeFilePreviewer(),
          attach_mappings = function(prompt_bufnr, map)
            local toggle_hidden = function()
              local prompt = action_state.get_current_line()
              actions.close(prompt_bufnr)

              local next_opts = vim.tbl_extend("force", opts, {
                default_text = prompt,
                hidden = not hidden,
              })

              _G.HuixTelescopeFindFiles(next_opts)
            end

            map("i", "<C-h>", toggle_hidden)
            map("n", "<C-h>", toggle_hidden)

            return true
          end,
        }, opts)

        builtin.find_files(picker_opts)
      end

      -- LazyGit Close Fix for Terminal
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          local opts = {buffer = 0}
          -- vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], opts)
          vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
          vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
          vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
          vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)
        end,
      })
    '';
  };
}
