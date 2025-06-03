return {
  'akinsho/git-conflict.nvim',
  version = "*",
  config = true,
  opts = {
    default_mappings = false
  },
  keys = {
    { "<Leader>co", "<Cmd>GitConflictChooseOurs<CR>",   desc = "Git Conflict choose ours" },
    { "<Leader>ct", "<Cmd>GitConflictChooseTheirs<CR>", desc = "Git Conflict choose theirs" },
    { "<Leader>cb", "<Cmd>GitConflictChooseBoth<CR>",   desc = "Git Conflict choose both" },
    { "<Leader>c0", "<Cmd>GitConflictChooseNone<CR>",   desc = "Git Conflict choose none" },
    { "<Leader>cn", "<Cmd>GitConflictNextConflict<CR>", desc = "Git Conflict next conflict" },
    { "<Leader>cp", "<Cmd>GitConflictPrevConflict<CR>", desc = "Git Conflict previous conflict" },
    { "<Leader>cq", "<Cmd>GitConflictListQf<CR>", desc = "Git Conflict quickfix" },
  }
}
