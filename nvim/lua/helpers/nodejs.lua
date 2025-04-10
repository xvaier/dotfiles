local function get_npm_global_path()
  local handle = io.popen("npm root -g")
  if not handle then return nil end

  local result = handle:read("*a")
  handle:close()
  return vim.fn.trim(result)
end

return {
  get_npm_global_path = get_npm_global_path
}
