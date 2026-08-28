require("gitsigns").setup({
  signcolumn = false,
  numhl = true,
  current_line_blame_opts = {
    delay = 300,
  },
})

vim.keymap.set("n", "<Leader>gcn", "<Cmd>Gitsigns next_hunk<CR>", { desc = "Go to next change" })
vim.keymap.set("n", "<Leader>gcp", "<Cmd>Gitsigns prev_hunk<CR>", { desc = "Go to previous change" })
vim.keymap.set("n", "<Leader>b", "<Cmd>Gitsigns toggle_current_line_blame<CR>", { desc = "Toggle git blame" })

vim.keymap.set("n", "<leader>gb", function()
  local file = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  local dir = vim.fn.expand("%:p:h")
  local blame = vim
    .system({ "git", "-C", dir, "blame", "-L", line .. "," .. line, "--porcelain", file }, { text = true })
    :wait()
  local sha = blame.code == 0 and blame.stdout:match("^(%x+)")
  if not sha or sha:match("^0+$") then
    vim.notify("No commit for this line", vim.log.levels.WARN)
    return
  end
  local remote = vim.system({ "git", "-C", dir, "remote", "get-url", "origin" }, { text = true }):wait()
  if remote.code ~= 0 then
    vim.notify("No origin remote", vim.log.levels.WARN)
    return
  end
  local url = vim.trim(remote.stdout):gsub("^git@(.-):", "https://%1/"):gsub("%.git$", "")
  vim.ui.open(url .. "/commit/" .. sha)
end, { desc = "Open blame commit URL" })
