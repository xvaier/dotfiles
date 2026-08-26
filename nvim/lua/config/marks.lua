-- Show letter marks in the sign column
local ns = vim.api.nvim_create_namespace("marks")

local function refresh(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local name = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_line_count(buf)
  local marks = vim.fn.getmarklist(buf)

  -- global marks span every file, so keep only the ones pointing at this buffer
  for _, mark in ipairs(vim.fn.getmarklist()) do
    if vim.fn.fnamemodify(mark.file, ":p") == name then
      table.insert(marks, mark)
    end
  end

  for _, mark in ipairs(marks) do
    local letter = mark.mark:sub(2)
    local lnum = mark.pos[2]
    if letter:match("^%a$") and lnum >= 1 and lnum <= lines then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
        sign_text = letter,
        sign_hl_group = "Identifier",
      })
    end
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
  desc = "Redraw mark signs",
  group = vim.api.nvim_create_augroup("marks", { clear = true }),
  callback = function(args)
    refresh(args.buf)
  end,
})

-- setting a mark fires no event, so wrap the key
vim.keymap.set("n", "m", function()
  pcall(vim.cmd, "normal! m" .. vim.fn.getcharstr())
  refresh(0)
end, { desc = "Set mark" })

local function refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh(buf)
  end
end

return { refresh = refresh, refresh_all = refresh_all }
