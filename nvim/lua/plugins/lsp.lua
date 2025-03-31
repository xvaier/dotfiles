return {
  {
    'williamboman/mason.nvim',
    lazy = false,
    opts = {},
  },
  -- vim typing for vim dev
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    config = function()
      local cmp = require('cmp')

      cmp.setup({
        sources = {
          { name = 'nvim_lsp' },
        },
        mapping = cmp.mapping.preset.insert({
          ['C-Y'] = cmp.mapping.confirm { select = true },
        }),
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
      })
    end
  },
  -- LSP
  {
    'neovim/nvim-lspconfig',
    cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'williamboman/mason.nvim' },
      { 'williamboman/mason-lspconfig.nvim' },
    },
    init = function()
      vim.opt.signcolumn = 'yes'
    end,
    config = function()
      local lspconfig = require('lspconfig')
      local lsp_defaults = lspconfig.util.default_config

      lsp_defaults.capabilities = vim.tbl_deep_extend(
        'force',
        lsp_defaults.capabilities,
        require('cmp_nvim_lsp').default_capabilities()
      )

      vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'LSP actions',
        callback = function(event)
          local opts = { buffer = event.buf }

          vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>',
            vim.tbl_extend("force", opts, { desc = "Show hover information" }))
          vim.keymap.set('n', '<leader>gd', '<cmd>lua vim.lsp.buf.definition()<cr>',
            vim.tbl_extend("force", opts, { desc = "Go to definition" }))
          vim.keymap.set('n', '<leader>gD', '<cmd>lua vim.lsp.buf.declaration()<cr>',
            vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
          vim.keymap.set('n', '<leader>gi', '<cmd>lua vim.lsp.buf.implementation()<cr>',
            vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
          vim.keymap.set('n', '<leader>go', '<cmd>lua vim.lsp.buf.type_definition()<cr>',
            vim.tbl_extend("force", opts, { desc = "Go to type definition" }))
          vim.keymap.set('n', '<leader>gr', '<cmd>lua vim.lsp.buf.references()<cr>',
            vim.tbl_extend("force", opts, { desc = "Find references" }))
          vim.keymap.set('n', '<leader>gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>',
            vim.tbl_extend("force", opts, { desc = "Show signature help" }))
          vim.keymap.set('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<cr>',
            vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
          vim.keymap.set('n', '<leader>f', '<cmd>lua vim.lsp.buf.format({async = true})<cr>',
            vim.tbl_extend("force", opts, { desc = "Format document" }))
          vim.keymap.set('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<cr>',
            vim.tbl_extend("force", opts, { desc = "Show code actions" }))
        end,
      })

      require('mason-lspconfig').setup({
        ensure_installed = { 'volar', 'tsserver', 'tflint' },
        automatic_installation = {},
        handlers = {
          function(server_name)
            require('lspconfig')[server_name].setup({})
          end,
        }
      })



      -- Python
      lspconfig.ruff.setup({
        init_options = {
          settings = {
            configurationPreference = "filesystemFirst"
          }
        }
      })

      lspconfig.pyright.setup {
        settings = {
          pyright = {
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              ignore = { '*' },
            },
          },
        },
      }

      -- Vue
      lspconfig.tsserver.setup {
        init_options = {
          plugins = {
            {
              name = "@vue/typescript-plugin",
              location = "/opt/homebrew/lib/node_modules/@vue/typescript-plugin",
              languages = { "javascript", "typescript", "vue" },
            },
          },
        },
        filetypes = {
          "javascript",
          "typescript",
          "vue",
        },
      }

      lspconfig.volar.setup {
        filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
        init_options = {
          vue = {},
        },
      }

      -- Eslint for js/ts
      lspconfig.eslint.setup({
        on_attach = function(client, bufnr)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            command = "EslintFixAll",
          })
        end,
      })

      lspconfig.terraformls.setup({})
    end
  }
}
