local vtsls_pkg = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.exepath("vtsls")), ":h:h")

return {
  -- vue_ls bundles typescript 7 (tsgo), which lacks the classic server API;
  -- point it at vtsls's typescript 5 so both servers agree on the version
  cmd = { "vue-language-server", "--stdio", "--tsdk=" .. vtsls_pkg .. "/node_modules/typescript/lib" },
  on_attach = function(client)
    client.server_capabilities.semanticTokensProvider.full = true
  end,
}
