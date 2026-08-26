return {
  'lewis6991/gitsigns.nvim',
  event = "BufReadPost",
  -- git status on the line number, leaving the sign column to marks
  opts = {
    signcolumn = false,
    numhl = true,
  },
  keys = {
    { "<Leader>gcn", "<Cmd>Gitsigns next_hunk<CR>", desc = "Go to previous change" },
    { "<Leader>gcp", "<Cmd>Gitsigns prev_hunk <CR>", desc = "Go to next change" },
  }
}
