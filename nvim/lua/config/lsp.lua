vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
})

vim.keymap.set("n", "<leader>q", vim.diagnostic.setqflist, { desc = "Diagnostics to quickfix" })

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP actions",
  callback = function()
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Show hover information" })
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Expand diagnostic" })
    vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition" })
    vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
    vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
    vim.keymap.set("n", "<leader>go", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
    vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { desc = "Find references" })
    vim.keymap.set("n", "<leader>gs", vim.lsp.buf.signature_help, { desc = "Show signature help" })
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
  end,
})

-- an autocmd rather than an eslint on_attach: lspconfig's own on_attach is what
-- defines LspEslintFixAll, and a config-level on_attach would replace it
vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Apply eslint fixes on save",
  callback = function(args)
    if vim.lsp.get_client_by_id(args.data.client_id).name ~= "eslint" then
      return
    end
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = args.buf,
      command = "LspEslintFixAll",
      desc = "Apply eslint fixes on save",
    })
  end,
})
