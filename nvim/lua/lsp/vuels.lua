local npm_root = require("helpers.nodejs").get_npm_global_path()

vim.lsp.config['vue_ls'] = {
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { 'vue' },
  init_options = {
    vue = {
      hybridMode = true,
    },
    typescript = {
      tsdk = npm_root .. "/typescript/lib"
    }
  },
  on_new_config = function(new_config, new_root_dir)
    local lib_path = vim.fs.find('node_modules/typescript/lib', { path = new_root_dir, upward = true })[1]
    if lib_path then
      new_config.init_options.typescript = new_config.init_options.typescript or {}
    end
  end
}

vim.lsp.enable('vue_ls')
