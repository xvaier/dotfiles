local wk = require("which-key")

wk.setup({})

wk.add({
  { "<leader>c", group = "conflicts / code actions" },
  { "<leader>g", group = "goto" },
  { "<leader>gc", group = "changes" },
  { "<leader>l", group = "lsp" },
  { "<leader>s", group = "search" },
  { "<leader>t", group = "tabs" },
  { "<leader>tm", group = "move" },
  { "<leader>w", group = "surround" },
  { "<leader>y", group = "yank" },
})

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
