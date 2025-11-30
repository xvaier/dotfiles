local function ensure_installed(lsp_cmd)
  local registry = require("mason-registry")

  local pkg = registry.get_package(lsp_cmd)

  if not pkg:is_installed() then
    vim.cmd('MasonInstall ' + lsp_cmd)
  end
end

return {
  ensure_installed = ensure_installed
}
