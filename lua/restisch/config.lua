-- RESTisch configuration module
local M = {}

M.defaults = {
	width = 100,
	height = 50,
	border = "rounded",
	theme = "dracula",
	keymaps = {
		send = "<CR>",
		save = "<C-s>",
		load = "<C-o>",
		close = "q",
		add_header = "a",
		delete_header = "dd",
		method_select = "m",
		toggle_response_headers = "h",
		next_field = "<Tab>",
		prev_field = "<S-Tab>",
	},
	default_headers = {
		{ key = "Accept", value = "*/*" },
		{ key = "Content-Type", value = "application/json" },
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
	M.setup_highlights()
end

function M.setup_highlights()
	local hl = vim.api.nvim_set_hl

	-- Dracula-inspired theme
	hl(0, "RestischMethod", { fg = "#8be9fd", bold = true })
	hl(0, "RestischUrl", { fg = "#f8f8f2" })
	hl(0, "RestischHeader", { fg = "#bd93f9" })
	hl(0, "RestischHeaderKey", { fg = "#ff79c6" })
	hl(0, "RestischHeaderValue", { fg = "#f1fa8c" })
	hl(0, "RestischSuccess", { fg = "#50fa7b", bold = true })
	hl(0, "RestischRedirect", { fg = "#ffb86c", bold = true })
	hl(0, "RestischError", { fg = "#ff5555", bold = true })
	hl(0, "RestischTime", { fg = "#6272a4" })
	hl(0, "RestischBorder", { fg = "#6272a4" })
	hl(0, "RestischBorderActive", { fg = "#bd93f9", bold = true })
	hl(0, "RestischTitle", { fg = "#bd93f9", bold = true })
	hl(0, "RestischLabel", { fg = "#8be9fd" })
	hl(0, "RestischPrompt", { fg = "#50fa7b" })
	hl(0, "RestischCursorUrl", { bg = "#ff79c6" })
	hl(0, "RestischHelpBar", { fg = "#8be9fd", bg = "#383a59" })
	hl(0, "RestischWinbar", { fg = "#6272a4", bg = "#282a36" })
	hl(0, "RestischWinbarFill", { bg = "#282a36" })

	-- Per-method colors
	hl(0, "RestischMethodGET", { fg = "#50fa7b", bold = true })
	hl(0, "RestischMethodPOST", { fg = "#f1fa8c", bold = true })
	hl(0, "RestischMethodPUT", { fg = "#8be9fd", bold = true })
	hl(0, "RestischMethodPATCH", { fg = "#ffb86c", bold = true })
	hl(0, "RestischMethodDELETE", { fg = "#ff5555", bold = true })

	-- JSON syntax highlighting in response body
	hl(0, "RestischJsonKey", { fg = "#ff79c6" })
	hl(0, "RestischJsonString", { fg = "#f1fa8c" })
	hl(0, "RestischJsonNumber", { fg = "#bd93f9" })
	hl(0, "RestischJsonBoolean", { fg = "#8be9fd" })
	hl(0, "RestischJsonNull", { fg = "#8be9fd" })
	hl(0, "RestischJsonBrace", { fg = "#f8f8f2" })

	-- Dialog-specific highlights (more visible)
	hl(0, "RestischDialogBorder", { fg = "#ff79c6", bold = true }) -- Pink/magenta border
	hl(0, "RestischDialogNormal", { fg = "#f8f8f2", bg = "#44475a" }) -- Lighter background
	hl(0, "RestischDialogTitle", { fg = "#50fa7b", bg = "#44475a", bold = true }) -- Green title
end

function M.get()
	return M.options
end

return M
