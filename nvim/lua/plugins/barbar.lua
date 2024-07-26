return {
  'romgrk/barbar.nvim',
  dependencies = {
    'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
    'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
  },
  init = function()
    vim.g.barbar_auto_setup = false
    local map = vim.api.nvim_set_keymap

    -- Move to previous/next
    map('n', '<leader>bp', '<Cmd>BufferPrevious<CR>', { desc = '[P]revious Barbar [B]uffer' })
    map('n', '<leader>bn', '<Cmd>BufferNext<CR>', { desc = '[N]ext Barbar [B]uffer' })
    map('n', '<leader>bc', '<Cmd>BufferClose<CR>', { desc = '[C]lose Barbar [B]uffer' })
  end,
  opts = {},
  version = '^1.0.0', -- optional: only update when a new 1.x version is released
}
