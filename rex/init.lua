-- Migrated from ~/.tmux.conf (prefix ctrl+space)

local terminal = "com.superlogical.terminal"

local function foreground(block_id)
  local p = rex.block.call(terminal, "process", { block_id = block_id })
  return p and p.foreground or {}
end

-- Same test as tmux's @is_vim: ^g?(view|n?vim?x?)(diff)?$, ignoring case
local function is_vim(name)
  name = (name or ""):lower():gsub("diff$", ""):gsub("^g", "")
  return name == "view" or name:match("^n?vim?x?$") ~= nil
end

rex.action{
  name  = "vim_navigate",
  title = "Navigate Panes or Vim Splits",
  args  = { direction = "string" },
  run   = function(ctx, args)
    if is_vim(foreground(ctx.block_id).name) then
      local keys = { left = "ctrl+h", down = "ctrl+j", up = "ctrl+k", right = "ctrl+l" }
      rex.client.queue("pane.send_key", { key = keys[args.direction] })
    else
      rex.session.focus_direction{ direction = args.direction, wrap = true }
    end
  end,
}

rex.action{
  name  = "popup",
  title = "Open Command in Floating Pane",
  args  = { command = "array", size = "number" },
  run   = function(ctx, args)
    local s = args.size
    local _, err = rex.session.new_layer{
      bounds = { (1 - s) / 2, (1 - s) / 2, s, s },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        options = { command = args.command, cwd = foreground(ctx.block_id).cwd },
      },
    }
    if err ~= nil then error(err, 0) end
  end,
}

rex.bind("ctrl+h", "vim_navigate", { direction = "left" })
rex.bind("ctrl+j", "vim_navigate", { direction = "down" })
rex.bind("ctrl+k", "vim_navigate", { direction = "up" })
rex.bind("ctrl+l", "vim_navigate", { direction = "right" })

rex.bind("ctrl+space>g", "popup", { command = { "lazygit" }, size = 0.9 })

rex.bind("ctrl+space>ctrl+space", "pane.send_key", { key = "ctrl+space" })

rex.bind("ctrl+space>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+space>-", "pane.split", { direction = "down" })
rex.bind("ctrl+space>c", "client.tab.new")

rex.bind("ctrl+space>r", "client.config.reload")

rex.bind("ctrl+space>s", "session.switch")
rex.bind("ctrl+space>w", "session.switch")

rex.bind("ctrl+space>up", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+space>down", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+space>left", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+space>right", "pane.resize", { amount = 5, direction = "right" })
rex.bind("ctrl+space>m", "pane.zoom")

-- tmux `bind -r` repeatable bindings: ctrl+space then ctrl+r enters, enter/escape leaves
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+space>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind("repeat/up", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/down", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/left", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/right", "pane.resize", { amount = 5, direction = "right" })
rex.bind("repeat/m", "pane.zoom")

-- tmux defaults on the prefix, mirroring Rex's own shortcuts
rex.bind("ctrl+space>x", "pane.close")
rex.bind("ctrl+space>shift+7", "client.tab.close")
rex.bind("ctrl+space>n", "client.tab.next")
rex.bind("ctrl+space>p", "client.tab.previous")
for i = 1, 9 do
  rex.bind("ctrl+space>" .. i, "client.tab.goto", { index = i })
end
rex.bind("ctrl+space>,", "client.tab.rename")
rex.bind("ctrl+space>shift+4", "session.rename")
rex.bind("ctrl+space>shift+9", "session.previous")
rex.bind("ctrl+space>shift+0", "session.next")
rex.bind("ctrl+space>shift+s", "session.new")
rex.bind("ctrl+space>o", "pane.focus_next")
rex.bind("ctrl+space>z", "pane.zoom")
rex.bind("ctrl+space>shift+1", "pane.move_to_new_tab")
rex.bind("ctrl+space>shift+e", "pane.balance")
rex.bind("ctrl+space>shift+;", "client.palette.toggle")
rex.bind("ctrl+space>f", "pane.float")
rex.bind("ctrl+space>/", "client.find.open")
