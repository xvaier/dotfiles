vim.opt.winborder = "rounded"

-- private API: the module path has already moved once and may again on upgrade
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
