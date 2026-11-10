vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = { current_line = true },
  signs = true,
  underline = true,
  update_in_insert = false,
})

vim.keymap.set("n", "<leader>q", vim.diagnostic.setqflist, { desc = "Diagnostics to quickfix" })

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP actions",
  callback = function()
    -- fzf-lua jumps straight to a single result and opens a picker for several
    local fzf = require("fzf-lua")
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Show hover information" })
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Expand diagnostic" })
    vim.keymap.set("n", "<leader>gd", fzf.lsp_definitions, { desc = "Go to definition" })
    vim.keymap.set("n", "<leader>gD", fzf.lsp_declarations, { desc = "Go to declaration" })
    vim.keymap.set("n", "<leader>gi", fzf.lsp_implementations, { desc = "Go to implementation" })
    vim.keymap.set("n", "<leader>go", fzf.lsp_typedefs, { desc = "Go to type definition" })
    vim.keymap.set("n", "<leader>gr", fzf.lsp_references, { desc = "Find references" })
    vim.keymap.set("n", "<leader>gs", vim.lsp.buf.signature_help, { desc = "Show signature help" })
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
    vim.keymap.set("n", "<leader>li", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
    end, { desc = "Toggle inlay hints" })
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
