return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- main branch does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")

    local ensure_installed = {
      "lua", "vimdoc", "javascript", "typescript", "html", "python", "terraform", "hcl",
    }
    local installed = require("nvim-treesitter.config").get_installed()
    local to_install = vim.tbl_filter(function(parser)
      return not vim.tbl_contains(installed, parser)
    end, ensure_installed)
    if #to_install > 0 then
      ts.install(to_install)
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
            return
          end
          vim.schedule(function()
            pcall(vim.treesitter.start, args.buf, lang)
          end)
        end)
      end,
    })
  end,
}
