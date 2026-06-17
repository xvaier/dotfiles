return {
  'lewis6991/gitsigns.nvim',
  event = "BufReadPost",
  opts = {},
  keys = {
    { "<Leader>gcn", "<Cmd>Gitsigns next_hunk<CR>", desc = "Go to previous change" },
    { "<Leader>gcp", "<Cmd>Gitsigns prev_hunk <CR>", desc = "Go to next change" },
  }
}
