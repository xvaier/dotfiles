local conditions = {
  buffer_not_empty = function()
    return vim.fn.empty(vim.fn.expand('%:t')) ~= 1
  end,
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end,
  check_git_workspace = function()
    local filepath = vim.fn.expand('%:p:h')
    local gitdir = vim.fn.finddir('.git', filepath .. ';')
    return gitdir and #gitdir > 0 and #gitdir < #filepath
  end,
}

return {
  "https://github.com/nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      component_separators = "",
      section_separators = "",
    },
    extensions = { 'oil', 'quickfix', 'fzf' },
    sections = {
      lualine_a = { {
        "mode",
        fmt = function(str) return str:sub(1, 1):lower() end
      } },
      lualine_b = { {
        "branch",
        icon = "",
      }, {
        "diff",
        symbols = { added = " ", modified = " ", removed = " " },
        cond = conditions.hide_in_width,
      }, {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = { error = " ", warn = " ", info = " " },
      } },
      lualine_c = {},
      lualine_y = {},
      lualine_z = {},
      lualine_x = { {
        "location",
        cond = conditions.buffer_not_empty,
      }, {
        "progress"
      }, {
        "encoding",
      }, {
        "lsp_status"
      }, {
        "filename",
        path = 1
      } },
    }
  }
}
