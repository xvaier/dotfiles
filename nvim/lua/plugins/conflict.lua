require("git-conflict").setup({
  default_mappings = false,
})

vim.keymap.set("n", "<Leader>co", "<Cmd>GitConflictChooseOurs<CR>", { desc = "Git Conflict choose ours" })
vim.keymap.set("n", "<Leader>ct", "<Cmd>GitConflictChooseTheirs<CR>", { desc = "Git Conflict choose theirs" })
vim.keymap.set("n", "<Leader>cb", "<Cmd>GitConflictChooseBoth<CR>", { desc = "Git Conflict choose both" })
vim.keymap.set("n", "<Leader>c0", "<Cmd>GitConflictChooseNone<CR>", { desc = "Git Conflict choose none" })
vim.keymap.set("n", "<Leader>cn", "<Cmd>GitConflictNextConflict<CR>", { desc = "Git Conflict next conflict" })
vim.keymap.set("n", "<Leader>cp", "<Cmd>GitConflictPrevConflict<CR>", { desc = "Git Conflict previous conflict" })
vim.keymap.set("n", "<Leader>cq", "<Cmd>GitConflictListQf<CR>", { desc = "Git Conflict quickfix" })
