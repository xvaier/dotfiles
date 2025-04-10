vim.lsp.config['terraformls'] = {
  cmd = { 'terraform-ls', 'serve' },
  filetypes = { 'terraform', 'tf' },
  settings = {}
}

vim.lsp.enable('terraformls')

