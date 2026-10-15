if vim.b.current_syntax then
  return
end

vim.cmd([[
  syntax match wtplanComment "^#.*$"
  syntax match wtplanPart "^\(part\|draft\)\>" nextgroup=wtplanNumber skipwhite
  syntax match wtplanNumber "#\d\+" contained
  syntax match wtplanPick "^pick\>" nextgroup=wtplanSha skipwhite
  syntax match wtplanHold "^hold\>" nextgroup=wtplanSha skipwhite
  syntax match wtplanSha "\x\{4,40}" contained
]])

local ok, palettes = pcall(require, "catppuccin.palettes")
local c = ok and palettes.get_palette("mocha")
  or { overlay0 = "#6c7086", mauve = "#cba6f7", blue = "#89b4fa", red = "#f38ba8", peach = "#fab387" }

vim.api.nvim_set_hl(0, "wtplanComment", { fg = c.overlay0, italic = true, default = true })
vim.api.nvim_set_hl(0, "wtplanPart", { fg = c.mauve, bold = true, default = true })
vim.api.nvim_set_hl(0, "wtplanPick", { fg = c.blue, default = true })
vim.api.nvim_set_hl(0, "wtplanHold", { fg = c.red, default = true })
vim.api.nvim_set_hl(0, "wtplanSha", { fg = c.peach, default = true })
vim.api.nvim_set_hl(0, "wtplanNumber", { fg = c.peach, bold = true, default = true })

vim.b.current_syntax = "wtplan"
