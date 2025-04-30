return {
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "eslint",
          "lua_ls",
          "basedpyright",
          "ruff",
          "ts_ls",
          "volar",
        },
        automatic_installation = true,
      })
    end
  }
}
