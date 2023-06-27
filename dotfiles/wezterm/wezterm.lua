local wezterm = require("wezterm")
return {
	-- color_scheme = "nord",
	-- color_scheme = "Nord (base16)",
	-- color_scheme = "Nova (base16)",
	-- color_scheme = "nordfox",
	-- color_scheme = "Seafoam Pastel",
	-- color_scheme = "Solarized (light) (terminal.sexy)",
	-- color_scheme = "kanagawabones",
	-- color_scheme = "onedark",
	color_scheme = "everforest",

	font = wezterm.font_with_fallback({
		"JetBrainsMono Nerd Font",
		"Symbols Nerd Font Mono",
		"Symbols Nerd Font",
		"FiraCode Nerd Font Mono",
		"FiraCode Nerd Font",
	}),

	hide_tab_bar_if_only_one_tab = true,

	colors = {
		tab_bar = {},
	},
}
