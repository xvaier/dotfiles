return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  lazy = false,
  opts = {
    flavour = "mocha",
    integrations = {
      cmp = true,
      gitsigns = true,
      treesitter = true
    }
  },
  config = function()
    vim.cmd.colorscheme "catppuccin"
  end
}
