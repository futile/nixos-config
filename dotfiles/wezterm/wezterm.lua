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
	-- color_scheme = "everforest",
	-- color_scheme = "Rosé Pine (base16)",
	-- color_scheme = "rose-pine",
	-- color_scheme = "Rosé Pine (Gogh)",
	-- color_scheme = "Rosé Pine Moon (base16)",
	-- color_scheme = "Rosé Pine Moon (Gogh)",
	-- color_scheme = "rose-pine-dawn",
	color_scheme = "Sakura (base16)",

	font = wezterm.font_with_fallback({
		-- "FantasqueSansM Nerd Font Mono", -- I just can't use this, not pleasent enough xd
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
