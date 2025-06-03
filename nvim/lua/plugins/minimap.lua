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
    local codewindow = require("codewindow")
    codewindow.setup(opts)
    codewindow.apply_default_keybinds()
  end,
}
