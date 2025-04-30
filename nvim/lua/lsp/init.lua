vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
})

vim.api.nvim_create_autocmd('LspAttach', {
  desc = 'LSP actions',
  callback = function()
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = "Show hover information" })
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Expand diagnostic" })
    vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, { desc = "Go to definition" })
    vim.keymap.set('n', '<leader>gD', vim.lsp.buf.declaration, { desc = "Go to declaration" })
    vim.keymap.set('n', '<leader>gi', vim.lsp.buf.implementation, { desc = "Go to implementation" })
    vim.keymap.set('n', '<leader>go', vim.lsp.buf.type_definition, { desc = "Go to type definition" })
    vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, { desc = "Find references" })
    vim.keymap.set('n', '<leader>gs', vim.lsp.buf.signature_help, { desc = "Show signature help" })
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = "Rename symbol" })
    vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end,
      { desc = "Format document" })
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = "Show code actions" })
  end,
})

-- load language server configs
require("lsp.luals")
require("lsp.basedpyright")
require("lsp.ruff")
require("lsp.terraformls")
require("lsp.volar")
require("lsp.tsls")
