return {
  "gorbit99/codewindow.nvim",
  event = "VeryLazy", -- or "BufReadPost" if you want it earlier
  opts = {
    auto_enable = false,
    exclude_filetypes = { "oil" },
    use_treesitter = true,
    use_git = true,
    use_diagnostics = true,
    window_border = false,
  },
  config = function(_, opts)
    -- codewindow.nvim is unmaintained and requires nvim-treesitter's `ts_utils`
    -- at load time. The main branch removed that module, so we shim the single
    -- function it uses (get_vim_range) on top of the native treesitter API.
    -- Registered before require("codewindow") so the load-time require resolves.
    package.preload["nvim-treesitter.ts_utils"] = function()
      return {
        -- Convert a 0-indexed {srow, scol, erow, ecol} node range to a 1-indexed
        -- Vim range, matching the original nvim-treesitter implementation.
        get_vim_range = function(range, buf)
          local srow, scol, erow, ecol = unpack(range)
          srow = srow + 1
          scol = scol + 1
          erow = erow + 1
          if ecol == 0 then
            erow = erow - 1
            if not buf or buf == 0 then
              ecol = vim.fn.col({ erow, "$" }) - 1
            else
              ecol = #(vim.api.nvim_buf_get_lines(buf, erow - 1, erow, false)[1] or "")
            end
            ecol = math.max(ecol, 1)
          end
          return srow, scol, erow, ecol
        end,
      }
    end

    local codewindow = require("codewindow")
    codewindow.setup(opts)
    codewindow.apply_default_keybinds()
  end,
}
