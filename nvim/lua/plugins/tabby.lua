return {
  "nanozuki/tabby.nvim",
  opts = {},
  keys = {
    { "<Leader>ta",  "<Cmd>$tabnew<CR>",     desc = "Tab: New at end",   mode = "n", silent = true },
    { "<Leader>tc",  "<Cmd>tabclose<CR>",    desc = "Tab: Close",        mode = "n", silent = true },
    { "<Leader>to",  "<Cmd>tabonly<CR>",     desc = "Tab: Close others", mode = "n", silent = true },
    { "<Leader>tn",  "<Cmd>tabnext<CR>",     desc = "Tab: Next",         mode = "n", silent = true },
    { "<Leader>tp",  "<Cmd>tabprevious<CR>", desc = "Tab: Previous",     mode = "n", silent = true },
    { "<Leader>tmp", "<Cmd>:-tabmove<CR>",   desc = "Tab: Move left",    mode = "n", silent = true },
    { "<Leader>tmn", "<Cmd>:+tabmove<CR>",   desc = "Tab: Move right",   mode = "n", silent = true },
    {
      "<Leader>tr",
      function()
        local name = vim.fn.input("New Name: ")
        if name ~= nil and name ~= "" then
          vim.api.nvim_cmd({ cmd = "Tabby", args = { "rename_tab", name } }, {})
        end
      end,
      desc = "Tab: Rename",
      mode = "n",
      silent = true,
    },
  },
}
