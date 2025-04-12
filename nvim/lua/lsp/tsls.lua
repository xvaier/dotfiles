local npm_root = require("helpers.nodejs").get_npm_global_path()

vim.lsp.config['tsls'] = {
  cmd = { "typescript-language-server", "--stdio" },
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
  settings = {}
}

vim.lsp.enable('tsls')
