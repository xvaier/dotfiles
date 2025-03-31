return {
  "f-person/git-blame.nvim",
  opts = {
    enabled = true,
    message_template = " <author> <date>: <summary>",
    date_format = "%r",
    virtual_text_column = 1,
  },
  lazy = false,
  keys = {
    { "<Leader>gb", "<Cmd>GitBlameOpenCommitURL<CR>", desc = "Go to blame commit URL" },
    { "<Leader>sf", "<Cmd>Files<CR>",                 desc = "Search files" },
  }
}
