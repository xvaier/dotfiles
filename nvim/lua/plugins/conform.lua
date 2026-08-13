return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true })
			end,
			mode = "",
			desc = "Format buffer",
		},
	},
	---@module "conform"
	---@type conform.setupOpts
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			ocaml = { "ocamlformat" },
			-- tofu, not terraform: only the OpenTofu CLI is installed
			terraform = { "tofu_fmt" },
			["terraform-vars"] = { "tofu_fmt" },
		},
		default_format_opts = {
			lsp_format = "fallback",
		},
		format_on_save = {
			timeout_ms = 1000,
			lsp_format = "fallback",
		},
		formatters = {
			shfmt = {
				append_args = { "-i", "2" },
			},
		},
	},
}
