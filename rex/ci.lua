-- Open bin/ci-watch in a small pane under the focused one, in its directory.

local term = require("terminal")

rex.action{
  name  = "ci_watch",
  title = "Watch CI for This Branch's MRs",
  run   = function(ctx)
    local _, err = rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = "vertical",
      side      = "after",
      ratio     = 0.75,
      layout    = rex.layout.block{
        flavor  = term.shell,
        label   = "ci",
        options = {
          command = { term.bin .. "ci-watch" },
          cwd     = term.foreground(ctx.block_id).cwd,
        },
      },
    }
    if err ~= nil then error(err, 0) end
  end,
}

rex.bind("ctrl+space>i", "ci_watch")
