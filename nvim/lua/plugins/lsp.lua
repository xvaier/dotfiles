return {
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

      local Path = require('plenary.path')

      local function find_venv(root_dir)
        local venv_dirs = { "venv", ".venv" }
        for i, venv_dir in ipairs(venv_dirs) do
          local venv = Path:new(root_dir, venv_dir)

          if venv:joinpath("bin"):is_dir() then
            return tostring(venv:joinpath("bin", "python"))
          end
        end
      end

      lsp_defaults.capabilities = vim.tbl_deep_extend(
        'force',
        lsp_defaults.capabilities,
        require('cmp_nvim_lsp').default_capabilities()
      )

      lsp_defaults.flags = vim.tbl_deep_extend(
        'force',
        lsp_defaults.flags or {},
        { debounce_text_changes = 150 }
      )

      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'LSP actions',
        callback = function()
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = "Show hover information" })
          vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Expand diagnostic" })
          vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, { desc = "Go to definition" })
          vim.keymap.set('n', '<leader>gD', vim.lsp.buf.declaration, { desc = "Go to declaration" })
          vim.keymap.set('n', '<leader>gi', vim.lsp.buf.implementation, { desc = "Go to implementation" })
          vim.keymap.set('n', '<leader>go', vim.lsp.buf.type_definition, { desc = "Go to type definition" })
          vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, { desc = "Find references" })
          vim.keymap.set('n', '<leader>gs', vim.lsp.buf.signature_help, { desc = "Show signature help" })
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = "Rename symbol" })
          vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end,
            { desc = "Format document" })
          vim.keymap.set('n', '<leader>ga', vim.lsp.buf.code_action, { desc = "Show code actions" })
        end,
      })

      require('mason-lspconfig').setup({
        ensure_installed = { 'ts_ls', 'tflint', 'pyright' },
        automatic_installation = {},
        handlers = {
          function(server_name)
            require('lspconfig')[server_name].setup({})
          end,
        }
      })



      -- Python
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
        before_init = function(params, config)
          local venv = find_venv(config.root_dir)
          print(vim.inspect(venv))
          if venv ~= nil then
            config.settings.python.pythonPath = venv
          else
            for root_dir in vim.fs.parents(config.root_dir) do
              venv = find_venv(root_dir)
              if venv ~= nil then
                config.settings.python.pythonPath = venv
                break
              end
            end
          end
        end
      }

      lspconfig.ruff.setup({
        init_options = {
          settings = {
            configurationPreference = "filesystemFirst"
          }
        }
      })
      lspconfig.pyright.setup {

      }

      -- Vue
      lspconfig.ts_ls.setup {
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

      -- terraform
      lspconfig.terraformls.setup {}
    end
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
  }
}
