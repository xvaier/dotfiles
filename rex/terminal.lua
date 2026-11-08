local M = {}

M.creator = "com.superlogical.terminal"
M.shell = "com.superlogical.terminal.shell"
M.bin = os.getenv("HOME") .. "/.config/rex/bin/"

function M.foreground(block_id)
  local p = rex.block.call(M.creator, "process", { block_id = block_id })
  return p and p.foreground or {}
end

return M
