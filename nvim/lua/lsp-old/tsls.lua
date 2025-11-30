local npm_root = require("helpers.nodejs").get_npm_global_path()

vim.lsp.config['ts_ls'] = {
  filetypes = { "vue", "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = npm_root .. "/@vue/typescript-plugin",
        languages = { "javascript", "typescript", "vue" },
      },
    },
  },
}
