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
    { "<Leader>gb", "<Cmd>GitBlameOpenCommitURL<CR>", desc = "[g]o to [b]lame commit URL" },
    { "<Leader>sf", "<Cmd>Files<CR>",                 desc = "[s]earch [f]iles" },
  }
}
