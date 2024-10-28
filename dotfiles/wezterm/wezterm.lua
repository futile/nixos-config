local wezterm = require("wezterm")
local hostname = wezterm.hostname()

local default_prog = nil
local set_environment_variables = nil
local term = nil
local font_size = nil

if hostname == "H77QF74G0F" then
	default_prog = { "fish", "--login" }
	set_environment_variables = {
		TERMINFO_DIRS = "/Users/frath/.nix-profile/share/terminfo",
		WSLENV = "TERMINFO_DIRS",
	}
	term = "wezterm"
	font_size = 13.2
end

return {
	-- color_scheme = "nord",
	-- color_scheme = "Nord (base16)",
	-- color_scheme = "Nova (base16)",
	-- color_scheme = "nordfox",
	-- color_scheme = "Seafoam Pastel",
	-- color_scheme = "Solarized (light) (terminal.sexy)",
	color_scheme = "kanagawabones",
	-- color_scheme = "onedark",
	-- color_scheme = "everforest",
	-- color_scheme = "Rosé Pine (base16)",
	-- color_scheme = "rose-pine",
	-- color_scheme = "Rosé Pine (Gogh)",
	-- color_scheme = "Rosé Pine Moon (base16)",
	-- color_scheme = "Rosé Pine Moon (Gogh)",
	-- color_scheme = "rose-pine-dawn",

	-- color_scheme = "Sakura (base16)",
	-- color_scheme = "embark",

	font = wezterm.font_with_fallback({
		-- "FantasqueSansM Nerd Font Mono", -- I just can't use this, not pleasent enough xd
		"JetBrainsMono Nerd Font",
		"Symbols Nerd Font Mono",
		"Symbols Nerd Font",
		"FiraCode Nerd Font Mono",
		"FiraCode Nerd Font",
	}),

	hide_tab_bar_if_only_one_tab = true,

	-- fix completely broken rendering on NixOS unstable: https://github.com/NixOS/nixpkgs/issues/336069
	front_end = "WebGpu",

	-- force_reverse_video_cursor = true,

	-- anti_alias_custom_block_glyphs = false,

	colors = {
		tab_bar = {},
	},

	default_prog = default_prog,
	set_environment_variables = set_environment_variables,
	term = term,
	font_size = font_size,
}
