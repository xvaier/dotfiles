return {
  "f-person/git-blame.nvim",
  opts = {
    enabled = false,
    message_template = " <author> <date>: <summary>",
    date_format = "%r",
  },
  lazy = false,
  keys = {
    { "<Leader>gb", "<Cmd>GitBlameOpenCommitURL<CR>", desc = "Go to blame commit URL" },
    { "<Leader>b", "<Cmd>GitBlameToggle<CR>", desc = "Toggle git blame" },
  }
}
