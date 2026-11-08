-- Review with tuicr in a float over the agent's pane. When tuicr copies the
-- review, bin/review-relay pastes it into that pane and submits it.

local term = require("terminal")

rex.action{
  name  = "review_relay",
  title = "Review Changes and Send to Agent",
  run   = function(ctx)
    local _, err = rex.invoke("popup", {
      command = { term.bin .. "review-relay", ctx.block_id },
      size    = 0.9,
    })
    if err ~= nil then error(err, 0) end
  end,
}

rex.bind("ctrl+space>v", "review_relay")
