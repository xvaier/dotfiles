local leader = "<leader>w"

require("mini.surround").setup({
  mappings = {
    add = leader .. "a",
    delete = leader .. "d",
    find = leader .. "f",
    find_left = leader .. "F",
    highlight = leader .. "h",
    replace = leader .. "r",
    update_n_lines = leader .. "n",
  },
})
