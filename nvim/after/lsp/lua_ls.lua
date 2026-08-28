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
