return {
	{
		"mason-org/mason.nvim",
		build = ":MasonUpdate",
		opts = {},
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason-org/mason-lspconfig.nvim",
			"yioneko/nvim-vtsls",
			"nvim-lua/plenary.nvim",
		},
		opts = {},
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"vtsls",
					"vue_ls",
					"eslint",
					"tailwindcss",
					"emmet_language_server",
					"lua_ls",
					"stylua",
					-- "ocamllsp",
					"ruff",
				},
				automatic_enable = false,
				automatic_installation = false,
			})

			local vue_language_server_path = vim.fn.expand("$MASON/packages")
				.. "/vue-language-server"
				.. "/node_modules/@vue/language-server"
			local vue_plugin = {
				name = "@vue/typescript-plugin",
				location = vue_language_server_path,
				languages = { "vue" },
				configNamespace = "typescript",
			}
			local vtsls_config = {
				settings = {
					vtsls = {
						tsserver = {
							globalPlugins = {
								vue_plugin,
							},
						},
					},
				},
				filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
			}
			local vue_ls_config = {
				init_options = {
					typescript = {},
				},
				on_attach = function(client)
					client.server_capabilities.semanticTokensProvider.full = true
				end,
			}
			vim.lsp.config("vtsls", vtsls_config)
			vim.lsp.config("vue_ls", vue_ls_config)

			vim.lsp.config("tailwindcss", {
				filetypes = {
					"aspnetcorerazor",
					"astro",
					"astro-markdown",
					"blade",
					"clojure",
					"django-html",
					"htmldjango",
					"edge",
					"eelixir",
					"elixir",
					"ejs",
					"erb",
					"eruby",
					"gohtml",
					"gohtmltmpl",
					"haml",
					"handlebars",
					"hbs",
					"html",
					"htmlangular",
					"html-eex",
					"heex",
					"jade",
					"leaf",
					"liquid",
					"markdown",
					"mdx",
					"mustache",
					"njk",
					"nunjucks",
					"php",
					"razor",
					"slim",
					"twig",
					"css",
					"less",
					"postcss",
					"sass",
					"scss",
					"stylus",
					"sugarss",
					"javascript",
					"javascriptreact",
					"reason",
					"rescript",
					"typescript",
					"typescriptreact",
					"vue",
					"svelte",
					"templ",
				},
				settings = {
					tailwindCSS = {
						classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
						includeLanguages = {
							eelixir = "html-eex",
							elixir = "phoenix-heex",
							eruby = "erb",
							heex = "phoenix-heex",
							htmlangular = "html",
							templ = "html",
						},
						lint = {
							cssConflict = "warning",
							invalidApply = "error",
							invalidConfigPath = "error",
							invalidScreen = "error",
							invalidTailwindDirective = "error",
							invalidVariant = "error",
							recommendedVariantOrder = "warning",
						},
						validate = true,
					},
				},
			})

			vim.lsp.config("emmet_language_server", {
				on_attach = function(client, bufnr)
					vim.keymap.set("i", "<c-s>,", function()
						client.request(
							"textDocument/completion",
							vim.lsp.util.make_position_params(0, client.offset_encoding),
							function(_, result)
								local textEdit = result.items[1].textEdit
								local snip_string = textEdit.newText
								textEdit.newText = ""
								vim.lsp.util.apply_text_edits({ textEdit }, bufnr, client.offset_encoding)
								require("luasnip").lsp_expand(snip_string)
							end,
							bufnr
						)
					end, { noremap = true, buffer = bufnr, desc = "Expand emmet" })
				end,
			})

			vim.lsp.config("lua_ls", {
				on_attach = function(client)
					client.server_capabilities.documentFormattingProvider = false
					client.server_capabilities.documentRangeFormattingProvider = false
				end,
				settings = {
					Lua = {
						workspace = {
							checkThirdParty = false,
						},
						completion = {
							callSnippet = "Replace",
						},
						telemetry = {
							enable = false,
						},
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			})

      local python_helper = require("helpers.python")
      vim.lsp.config("basedpyright", {
        before_init = function(_, config)
          local venv_python = python_helper.find_venv(config.root_dir or vim.fn.getcwd())
          if venv_python then
            config.settings = config.settings or {}
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = venv_python
          end
        end,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "standard",
              diagnosticMode = "openFilesOnly",
              autoImportCompletions = true,
            },
          },
        },
      })

      vim.lsp.config("saturn_lsp", {
        cmd = { vim.fn.expand("~/Developer/flare/pyro/bin/saturn-lsp") },
        filetypes = { "yaml" },
        root_markers = { ".git" },
      })

      vim.lsp.enable("lua_ls")
      vim.lsp.enable("ruff")
      vim.lsp.enable("basedpyright")
			vim.lsp.enable("vtsls")
			vim.lsp.enable("vue_ls")
			vim.lsp.enable("ts_ls")
			vim.lsp.enable("tailwindcss")
			vim.lsp.enable("eslint")
			vim.lsp.enable("saturn_lsp")

		end,
	},
}
