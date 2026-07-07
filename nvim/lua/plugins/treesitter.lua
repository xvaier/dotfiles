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

    -- Highlighting is now Neovim's job; start it per buffer.
    -- Unscoped + pcall so it no-ops for filetypes without a parser
    -- (avoids parser-name vs filetype mismatches, e.g. vimdoc/help).
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
