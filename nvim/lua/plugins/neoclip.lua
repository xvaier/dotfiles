return {
  "AckslD/nvim-neoclip.lua",
  dependencies = {
    { 'ibhagwan/fzf-lua' },
  },
  config = function()
    require('neoclip').setup()
  end,
  event = { "VimEnter" },
  keys = {
    { "<Leader>sy", function() require('neoclip.fzf')() end, desc = "Search register history" },
  },
}
