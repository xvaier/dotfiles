return {
  "f-person/git-blame.nvim",
  opts = {
    enabled = true,
    message_template = " <author> <date>: <summary>",
    date_format = "%r",
    display_virtual_text = 0,
  },
  lazy = false,
  keys = {
    { "<Leader>gb", "<Cmd>GitBlameOpenCommitURL<CR>", desc = "Go to blame commit URL" },
  }
}
