-- Hyprland Lua config — entry point

--------------------------------
---- LAYOUT CONFIGURATIONS -----
--------------------------------

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({
	master = {
		new_status = "master",
	},
})

hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = false,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
	},
})

-----------------
---- MODULES ----
-----------------

require("lua/monitor")
require("lua/env")
require("lua/autostart")
require("lua/look_and_feel")
require("lua/animations")
require("lua/input")
require("lua/keybindings")
require("lua/windowrules")
