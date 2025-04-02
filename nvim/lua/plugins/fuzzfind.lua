return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<Leader>sf", function() require("fzf-lua").files() end,               desc = "Search files" },
      { "<Leader>sg", function() require("fzf-lua").git_files() end,           desc = "Search Git files" },
      { "<Leader>sc", function() require("fzf-lua").git_status() end,          desc = "Search Changed files" },
      { "<Leader>sb", function() require("fzf-lua").buffers() end,             desc = "Search Buffers" },
      { "<Leader>sr", function() require("fzf-lua").live_grep() end,           desc = "Search Ripgrep" },
      { "<Leader>sl", function() require("fzf-lua").lines() end,               desc = "Search lines in open buffers" },
    },
    config = function()
      require("fzf-lua").setup({
        winopts = { preview = { default = "bat" } }
      })
    end,
  },
}
