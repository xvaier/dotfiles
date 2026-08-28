local fzf = require("fzf-lua")

fzf.setup({
  marks = {
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
      layout = "vertical",
    },
  },
})
fzf.register_ui_select()

local pickers = {
  { "<Leader>sf", fzf.files, "Search files" },
  { "<Leader>sr", fzf.resume, "Resume last search" },
  { "<Leader>ss", fzf.lsp_document_symbols, "Search Buffer Symbols" },
  { "<Leader>sc", fzf.git_status, "Search Changed files" },
  { "<Leader>sb", fzf.buffers, "Search Buffers" },
  { "<Leader>sg", fzf.live_grep, "Search Ripgrep" },
  { "<Leader>sl", fzf.lines, "Search lines in open buffers" },
  { "<Leader>sm", fzf.marks, "Search marks" },
  { "<Leader>sd", fzf.diagnostics_workspace, "Search workspace diagnostics" },
  { "<Leader>sy", fzf.registers, "Search registers" },
  { "<Leader>ca", fzf.lsp_code_actions, "Search code actions" },
}

for _, picker in ipairs(pickers) do
  local lhs, fn, desc = picker[1], picker[2], picker[3]
  vim.keymap.set("n", lhs, fn, { desc = desc })
end

vim.keymap.set("v", "<Leader>sv", fzf.grep_visual, { desc = "Search current visual selection" })
