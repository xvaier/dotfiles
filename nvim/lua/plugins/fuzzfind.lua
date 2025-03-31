return {
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    keys = {
      { "<Leader>sf", "<Cmd>Files<CR>",         desc = "Search files" },
      { "<Leader>sg", "<Cmd>GFilesSafe<CR>",    desc = "Search Git files" },
      { "<Leader>sc", "<Cmd>GFilesChanged<CR>", desc = "Search Changed files" },
      { "<Leader>sb", "<Cmd>Buffers<CR>",       desc = "Search Buffers" },
      { "<Leader>sa", "<Cmd>Ag<CR>",            desc = "Search Ag (silver searcher)" },
      { "<Leader>sr", "<Cmd>Rg<CR>",            desc = "Search Rg (ripgrep)" },
      { "<Leader>sl", "<Cmd>Lines<CR>",         desc = "Search lines in open buffers" },
    },
    config = function()
      local function gfiles_safe(arg, bang)
        local cwd = vim.fn.getcwd()
        vim.fn["fzf#vim#gitfiles"](arg or "", { dir = cwd }, bang and 1 or 0)
      end

      vim.api.nvim_create_user_command("GFilesSafe", function(opts)
        gfiles_safe("", opts.bang)
      end, { bang = true })

      vim.api.nvim_create_user_command("GFilesChanged", function(opts)
        gfiles_safe("?", opts.bang)
      end, { bang = true })
    end,
  },
}
