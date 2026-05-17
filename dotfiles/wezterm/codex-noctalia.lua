local M = {}

local clear_script = "/home/felix/nixos/bin/codex-clear-noctalia-for-pane"
local last_pane_by_window = {}

local function clear_for_pane(wezterm, pane)
	if pane == nil then
		return
	end

	wezterm.background_child_process({
		clear_script,
		tostring(pane:pane_id()),
	})
end

function M.setup(wezterm)
	wezterm.on("window-focus-changed", function(window, pane)
		if not window:is_focused() then
			return
		end

		last_pane_by_window[window:window_id()] = pane:pane_id()
		clear_for_pane(wezterm, pane)
	end)

	wezterm.on("update-status", function(window, pane)
		if not window:is_focused() then
			return
		end

		local window_id = window:window_id()
		local pane_id = pane:pane_id()

		if last_pane_by_window[window_id] == pane_id then
			return
		end

		last_pane_by_window[window_id] = pane_id
		clear_for_pane(wezterm, pane)
	end)
end

return M
