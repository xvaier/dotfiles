vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

local function buffer_lines()
  return vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
end

vim.keymap.set("n", "<leader>ya", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute path to clipboard" })

vim.keymap.set("n", "<leader>yr", function()
  vim.fn.setreg("+", vim.fn.expand("%:."))
end, { desc = "Copy relative path to clipboard" })

vim.keymap.set("n", "<leader>yf", function()
  local lines = buffer_lines()
  table.insert(lines, 1, vim.fn.expand("%:."))
  vim.fn.setreg("+", table.concat(lines, "\n"))
end, { desc = "Copy relative path and buffer contents to clipboard" })

vim.keymap.set("n", "<leader>yb", function()
  vim.fn.setreg("+", table.concat(buffer_lines(), "\n"))
end, { desc = "Copy buffer contents to clipboard" })
