return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/neotest-python',
      'nvim-neotest/neotest-go',
      'nvim-neotest/neotest-jest',
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      local neotest = require 'neotest'
      ---@diagnostic disable-next-line: missing-fields
      neotest.setup {
        adapters = {
          require 'neotest-python',
          require 'neotest-go',
          require 'neotest-jest',
        },
      }

      local test_file = function()
        vim.cmd [[w]]
        neotest.run.run(vim.fn.expand '%')
      end

      local map = vim.keymap.set

      map('n', '<leader>tr', ':w<cr><Cmd>Neotest run<cr>', { desc = 'Neo[t]est [R]un' })
      map('n', '<leader>tf', test_file, { desc = 'Neo[t]est [f]ile' })
      map('n', '<leader>ts', '<Cmd>Neotest summary<cr>', { desc = 'Neo[t]est [S]ummary' })
      map('n', '<leader>to', '<Cmd>Neotest output<cr>', { desc = 'Neo[t]st [O]utput' })
    end,
  },
}
