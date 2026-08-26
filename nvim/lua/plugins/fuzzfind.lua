return {
  {
    "ibhagwan/fzf-lua",
    keys = {
      { "<Leader>sf", function() require("fzf-lua").files() end,                 desc = "Search files" },
      { "<Leader>sr", function() require("fzf-lua").resume() end,                desc = "Search Git files" },
      { "<Leader>ss", function() require("fzf-lua").lsp_document_symbols() end,  desc = "Search Buffer Symbols" },
      { "<Leader>sc", function() require("fzf-lua").git_status() end,            desc = "Search Changed files" },
      { "<Leader>sb", function() require("fzf-lua").buffers() end,               desc = "Search Buffers" },
      { "<Leader>sg", function() require("fzf-lua").live_grep() end,             desc = "Search Ripgrep" },
      { "<Leader>sl", function() require("fzf-lua").lines() end,                 desc = "Search lines in open buffers" },
      { "<Leader>sm", function() require("fzf-lua").marks() end,                 desc = "Search marks" },
      { "<Leader>sd", function() require("fzf-lua").diagnostics_workspace() end, desc = "Search workspace diagnostics" },
      { "<Leader>sv", function() require("fzf-lua").grep_visual() end,           desc = "Search current visual selection", mode = "v" },
      { "<Leader>ca", function() require("fzf-lua").lsp_code_actions() end,      desc = "Search code actions" },
    },
    config = function(_, opts)
      require("fzf-lua").setup(opts)
      require("fzf-lua").register_ui_select()
    end,
    opts = {
      marks = {
        -- letters only, hiding the auto-set ' " [ ] ^ . < > marks
        marks = "%a",
        fzf_opts = { ["--no-multi"] = false, ["--multi"] = true },
        actions = {
          ["ctrl-x"] = {
            fn = function(selected, o)
              require("fzf-lua.actions").mark_del(selected, o)
              require("config.marks").refresh_all()
            end,
            reload = true,
            header = "delete",
          },
        },
      },
      files = {
        cwd_prompt = false,
        prompt = "> ",
      },
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
