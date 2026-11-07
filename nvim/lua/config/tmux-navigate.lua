local labels = { h = "left", j = "down", k = "up", l = "right" }

for key, pane in pairs({ h = "L", j = "D", k = "U", l = "R" }) do
  vim.keymap.set("n", "<C-" .. key .. ">", function()
    if vim.fn.winnr(key) ~= vim.fn.winnr() then
      vim.cmd.wincmd(key)
    elseif vim.env.TMUX then
      vim.system({ "tmux", "select-pane", "-" .. pane })
    elseif vim.env.REX_SESSION then
      vim.system({ "rex", "focus", "-s", vim.env.REX_SESSION, labels[key], "--wrap" })
    end
  end, { desc = "Navigate split/pane " .. labels[key] })
end
