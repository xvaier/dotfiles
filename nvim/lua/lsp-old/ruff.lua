vim.lsp.config['ruff'] = {
  cmd = { "ruff", "server" },
  filetypes = { 'python' },
  root_dir = vim.fs.dirname(vim.fs.find({ "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" }, { upward = true })[1]),
  settings = {},
}

vim.lsp.enable('ruff')
