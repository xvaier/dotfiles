return {
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    keys = {
      { "<Leader>sf", "<Cmd>Files<CR>",         desc = "[s]earch [f]iles" },
      { "<Leader>sg", "<Cmd>GFilesSafe<CR>",    desc = "[s]earch [g]it files" },
      { "<Leader>sc", "<Cmd>GFilesChanged<CR>", desc = "[s]earch [c]hanged files" },
      { "<Leader>sb", "<Cmd>Buffers<CR>",       desc = "[s]earch [b]uffers" },
      { "<Leader>sa", "<Cmd>Ag<CR>",            desc = "[s]earch [a]g (silver searcher)" },
      { "<Leader>sr", "<Cmd>Rg<CR>",            desc = "[s]earch [r]g (ripgrep)" },
      { "<Leader>sl", "<Cmd>Lines<CR>",         desc = "[s]earch [l]ines in open buffers" },
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
