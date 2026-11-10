-- 'autoread' only checks on a few events; agents edit open files constantly
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  desc = "Reload buffers changed on disk",
  group = vim.api.nvim_create_augroup("reload", { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == "" and vim.bo.buftype == "" then
      vim.cmd.checktime()
    end
  end,
})
