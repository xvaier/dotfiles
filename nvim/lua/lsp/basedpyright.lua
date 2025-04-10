vim.lsp.config['basedpyright'] = {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_dir = vim.fs.dirname(vim.fs.find({ 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
    { upward = true })[1]),
  before_init = function(params, config)
    local venv = require("helpers.python").find_venv(config.root_dir)
    print(vim.inspect(venv))
    if venv ~= nil then
      config.settings.basedpyright.pythonPath = venv
    else
      for root_dir in vim.fs.parents(config.root_dir) do
        venv = require("helpers.python").find_venv(root_dir)
        if venv ~= nil then
          config.settings.basedpyright.pythonPath = venv
          break
        end
      end
    end
  end,
  settings = {
    basedpyright = {
      disableOrganizeImports = false,
      analysis = {
        autoSearchPaths = true,
        autoImportCompletions = true,
        typeCheckingMode = "standard",
        diagnosticMode = "openFilesOnly",
        useLibraryCodeForTypes = true,
      },
    },
  },
}

vim.lsp.enable('basedpyright')
