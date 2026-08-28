-- installed via npm -g alongside vue-language-server
local vue_pkg = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.exepath("vue-language-server")), ":h:h")

return {
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = {
          {
            name = "@vue/typescript-plugin",
            location = vue_pkg,
            languages = { "vue" },
            configNamespace = "typescript",
          },
        },
      },
    },
  },
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
}
