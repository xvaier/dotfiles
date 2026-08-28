-- fix-on-save lives in config/lsp.lua: it has to run alongside lspconfig's
-- on_attach (which defines LspEslintFixAll), not replace it
return {
  settings = {
    -- conform owns formatting; eslint only fixes lint rules
    format = false,
  },
}
