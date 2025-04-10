local Path = require "plenary.path"

local function find_venv(root_dir)
  local venv_dirs = {"venv", ".venv"}
  for i, venv_dir in ipairs(venv_dirs) do
    local venv = Path:new(root_dir, venv_dir)

    if venv:joinpath("bin"):is_dir() then
      return tostring(venv:joinpath("bin", "python"))
    end
  end
end

vim.lsp.config['basedpyright'] = {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_dir = vim.fs.dirname(vim.fs.find({ 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' }, { upward = true })[1]),
  capabilities = vim.lsp.capabilities,
  before_init = function(params, config)
    local venv = find_venv(config.root_dir)
    print(vim.inspect(venv))
    if venv ~= nil then
      config.settings.python.pythonPath = venv
    else
      for root_dir in vim.fs.parents(config.root_dir) do
        venv = find_venv(root_dir)
        if venv ~= nil then
          config.settings.python.pythonPath = venv
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
