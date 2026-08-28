require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    terraform = { "tofu_fmt" },
    ["terraform-vars"] = { "tofu_fmt" },
  },
  default_format_opts = {
    lsp_format = "fallback",
  },
  format_on_save = {
    timeout_ms = 1000,
    lsp_format = "fallback",
  },
})

vim.keymap.set({ "n", "v", "o" }, "<leader>f", function()
  require("conform").format({ async = true })
end, { desc = "Format buffer" })
