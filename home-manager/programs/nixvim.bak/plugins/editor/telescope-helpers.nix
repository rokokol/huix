{ ... }:

{
  programs.nixvim.extraConfigLua = ''
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

    local function attach_hidden_toggle(open_picker, opts, hidden)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      return function(prompt_bufnr, map)
        local toggle_hidden = function()
          local prompt = action_state.get_current_line()
          actions.close(prompt_bufnr)

          local next_opts = vim.tbl_extend("force", opts, {
            default_text = prompt,
            hidden = not hidden,
          })

          open_picker(next_opts)
        end

        map("i", "<C-h>", toggle_hidden)
        map("n", "<C-h>", toggle_hidden)

        return true
      end
    end

    local function open_toggleable_picker(open_picker, opts, picker_opts)
      opts = opts or {}

      local hidden = opts.hidden == true
      picker_opts = vim.tbl_extend("force", picker_opts or {}, opts)
      picker_opts.attach_mappings = attach_hidden_toggle(open_picker, opts, hidden)

      return open_picker(picker_opts)
    end

    _G.HuixTelescopeFindFiles = _G.HuixTelescopeFindFiles or function(opts)
      local builtin = require("telescope.builtin")

      opts = opts or {}

      return open_toggleable_picker(function(picker_opts)
        return builtin.find_files(picker_opts)
      end, opts, {
        hidden = opts.hidden == true,
        previewer = _G.HuixTelescopeFilePreviewer(),
      })
    end

    _G.HuixTelescopeLiveGrep = _G.HuixTelescopeLiveGrep or function(opts)
      local builtin = require("telescope.builtin")

      opts = opts or {}
      local hidden = opts.hidden == true

      return open_toggleable_picker(function(picker_opts)
        return builtin.live_grep(picker_opts)
      end, opts, {
        additional_args = function()
          local args = {}

          if hidden then
            table.insert(args, "--hidden")
          end

          return args
        end,
      })
    end

    local ok_project_actions, project_actions = pcall(require, "telescope._extensions.projects.actions")
    local ok_project_config, project_config = pcall(require, "project.config")

    if ok_project_actions and ok_project_config then
      local function open_project_files(prompt_bufnr)
        local project_path, cd_successful = project_actions.change_working_directory(prompt_bufnr)

        if not cd_successful then
          return
        end

        _G.HuixTelescopeFindFiles({
          cwd = project_path,
          cwd_to_path = true,
          hidden = project_config.options.show_hidden,
          hide_parent_dir = true,
          mode = "insert",
          path = project_path,
        })
      end

      project_actions.find_project_files = open_project_files
      project_actions.browse_project_files = open_project_files
    end
  '';
}
