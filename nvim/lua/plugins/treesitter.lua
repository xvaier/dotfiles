local ts = require("nvim-treesitter")

local function warn(msg, err)
  vim.schedule(function()
    local detail = type(err) == "string" and err or vim.inspect(err)
    vim.notify(msg .. ": " .. detail, vim.log.levels.WARN, { title = "nvim-treesitter" })
  end)
end

local ensure_installed = {
  "lua",
  "vimdoc",
  "javascript",
  "typescript",
  "html",
  "python",
  "terraform",
  "hcl",
}
local installed = require("nvim-treesitter.config").get_installed()
local to_install = vim.tbl_filter(function(parser)
  return not vim.tbl_contains(installed, parser)
end, ensure_installed)
if #to_install > 0 then
  ts.install(to_install):await(function(err)
    if err then
      warn("failed to install " .. table.concat(to_install, ", "), err)
    end
  end)
end

local available = require("nvim-treesitter.config").get_available()
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if not (lang and vim.tbl_contains(available, lang)) then
      return
    end
    ts.install(lang):await(function(err)
      if err then
        warn("failed to install parser for " .. lang, err)
        return
      end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(args.buf) then
          return
        end
        local ok, start_err = pcall(vim.treesitter.start, args.buf, lang)
        if not ok then
          warn("failed to start highlighting for " .. lang, start_err)
        end
      end)
    end)
  end,
})
