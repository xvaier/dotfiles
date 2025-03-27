return { {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      ensure_installed = { "lua", "vimdoc", "javascript", "typescript", "html", "python", "terraform", "hcl" },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      auto_install = true,
      modules = {},
      ignore_install = {}
    })
  end
} }
