-- color the current line number by mode, matching lualine's mode segment
local modes = {
  i = "insert",
  v = "visual",
  V = "visual",
  ["\22"] = "visual",
  R = "replace",
  c = "command",
  t = "terminal",
}

local base = vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false })

local function update()
  local mode = modes[vim.fn.mode():sub(1, 1)] or "normal"
  local hl = vim.api.nvim_get_hl(0, { name = "lualine_a_" .. mode, link = false })
  if hl.bg then
    vim.api.nvim_set_hl(0, "CursorLineNr", vim.tbl_extend("force", base, { fg = hl.bg }))
    if mode == "command" then
      -- the number column isn't repainted while the cmdline is open
      vim.cmd("redraw")
    end
  end
end

vim.api.nvim_create_autocmd("ModeChanged", {
  group = vim.api.nvim_create_augroup("mode-color", { clear = true }),
  callback = update,
})

-- ModeChanged doesn't fire for the mode we start in
update()
