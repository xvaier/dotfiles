return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<Leader>sf", function() require("fzf-lua").files() end,                 desc = "Search files" },
      { "<Leader>sr", function() require("fzf-lua").resume() end,                desc = "Search Git files" },
      { "<Leader>ss", function() require("fzf-lua").lsp_document_symbols() end,            desc = "Search Buffer Symbols" },
      { "<Leader>sc", function() require("fzf-lua").git_status() end,            desc = "Search Changed files" },
      { "<Leader>sb", function() require("fzf-lua").buffers() end,               desc = "Search Buffers" },
      { "<Leader>sg", function() require("fzf-lua").live_grep() end,             desc = "Search Ripgrep" },
      { "<Leader>sl", function() require("fzf-lua").lines() end,                 desc = "Search lines in open buffers" },
      { "<Leader>sd", function() require("fzf-lua").diagnostics_workspace() end, desc = "Search workspace diagnostics" },
    },
    opts = {
      winopts = {
        backdrop = 100,
        height = 0.95,
        width = 0.95,
        preview = {
          layout = "vertical"
        }
      }
    }
  }
}
