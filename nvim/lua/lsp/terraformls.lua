vim.lsp.config['terraformls'] = {
  cmd = { 'terraform-ls', 'serve' },
  filetypes = { 'terraform', 'tf' },
  capabilities = vim.lsp.capabilities,
  settings = {}
}

vim.lsp.enable('terraformls')

