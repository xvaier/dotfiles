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

return {
  find_venv = find_venv
}
