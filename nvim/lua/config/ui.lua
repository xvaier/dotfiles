vim.opt.winborder = "rounded"

require("vim._core.ui2").enable({
  enable = true,
  msg = {
    ---@type string|table<string, 'cmd'|'msg'|'pager'>
    targets = "cmd",
    dialog = {
      height = 0.5,
    },
    msg = {
      height = 0.5,
    },
    pager = {
      height = 0.999,
    },
  },
})
