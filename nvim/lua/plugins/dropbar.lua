return {
  'Bekaboo/dropbar.nvim',
  enabled = false,
  opts = { icons = { enable = false } },
  config = function()
    local dropbar_api = require('dropbar.api')
    vim.keymap.set('n', '<Leader>wb', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
  end
}
