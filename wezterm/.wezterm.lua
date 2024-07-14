local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "Tokyo Night Moon"
config.font = wezterm.font("Fira code")
config.font_size = 15
config.hide_tab_bar_if_only_one_tab = true

return config
