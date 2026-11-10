return {
  on_attach = function(client)
    -- conform owns lua formatting via stylua
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  settings = {
    Lua = {
      workspace = {
        checkThirdParty = false,
        -- types for vim.*; kept out of .luarc.json because the path is per machine
        library = { vim.env.VIMRUNTIME .. "/lua" },
      },
      completion = {
        callSnippet = "Replace",
      },
      telemetry = {
        enable = false,
      },
      diagnostics = {
        globals = { "vim" },
      },
    },
  },
}
