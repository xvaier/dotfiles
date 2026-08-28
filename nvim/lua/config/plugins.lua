local gh = function(repo)
  return "https://github.com/" .. repo
end

-- parsers must be recompiled when treesitter changes; a fresh install needs no
-- hook because plugins/treesitter.lua installs them itself
vim.api.nvim_create_autocmd("PackChanged", {
  desc = "Rebuild treesitter parsers after an update",
  callback = function(ev)
    if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      require("nvim-treesitter").update()
    end
  end,
})

vim.pack.add({
  -- the plugin dir must not be called "nvim"
  { src = gh("catppuccin/nvim"), name = "catppuccin" },
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  -- stay on tagged releases
  { src = gh("akinsho/git-conflict.nvim"), version = vim.version.range("*") },
  gh("neovim/nvim-lspconfig"),
  gh("echasnovski/mini.icons"),
  gh("stevearc/oil.nvim"),
  gh("malewicz1337/oil-git.nvim"),
  gh("stevearc/conform.nvim"),
  gh("lewis6991/gitsigns.nvim"),
  gh("nvim-lua/plenary.nvim"),
  gh("folke/todo-comments.nvim"),
  gh("folke/flash.nvim"),
  gh("ibhagwan/fzf-lua"),
  gh("echasnovski/mini.surround"),
  gh("folke/which-key.nvim"),
  gh("nvim-lualine/lualine.nvim"),
  -- install without prompting on a fresh clone
}, { confirm = false })

require("plugins.theme")
require("plugins.treesitter")
require("plugins.lspconfig")
require("plugins.filemanager")
require("plugins.conform")
require("plugins.gitsigns")
require("plugins.conflict")
require("plugins.todo-comments")
require("plugins.flash")
require("plugins.fuzzfind")
require("plugins.surround")
require("plugins.keyhints")
require("plugins.statusline")
