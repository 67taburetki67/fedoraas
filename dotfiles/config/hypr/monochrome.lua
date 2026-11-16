-- монохромная тема
hl.config({
  decoration = {
    blur = { enabled = true, size = 6, passes = 3, noise = 0.06 },
    screen_shader = "",
  },
})
-- рамки и анимации: скопируй структуру из /usr/share/hypr/hyprland.lua,
-- цвета рамок: активная 5a5a5e, неактивная 1c1c1e

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 10,
    border_size = 1,
    col = {
      active_border = "rgba(5a5a5eff)",
      inactive_border = "rgba(1c1c1eff)",
    },
  },
  decoration = {
    rounding = 0,
    shadow = { enabled = false },
  },
})

hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, bezier = "almostLinear", style = "popin 100%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "linear",       style = "popin 100%" })

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 10,
    border_size = 1,
    col = {
      active_border = "rgba(5a5a5eff)",
      inactive_border = "rgba(1c1c1eff)",
    },
  },
  decoration = {
    rounding = 0,
    shadow = { enabled = false },
  },
})


local mod = "SUPER"

hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))



local mod = "SUPER"






hl.config({
  general = { gaps_in = 5, gaps_out = 12, border_size = 1 },
  decoration = {
    rounding = 14,
    rounding_power = 2,
    active_opacity = 0.96,
    inactive_opacity = 0.88,
    shadow = { enabled = true, range = 24, render_power = 3, color = "rgba(00000099)" },
    blur = { enabled = true, size = 8, passes = 3, noise = 0.06, vibrancy = 0.1 },
  },
  misc = { force_default_wallpaper = 0, disable_hyprland_logo = true },
})

hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })

hl.layer_rule({ match = { namespace = "waybar" },  blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "swaync-.*" }, blur = true, ignore_alpha = 0.3 })

hl.on("hyprland.start", function()
end)


-- кривые
hl.curve("soft",      { type = "spring", mass = 1, stiffness = 90, dampening = 14 })
hl.curve("overshoot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

-- окна: мягкая пружина при открытии, плавное перемещение
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4, spring = "soft", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "soft" })

-- воркспейсы: скольжение с растворением
hl.animation({ leaf = "workspaces",    enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefadevert -50%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefadevert -50%" })

-- растворение и цвет рамки
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "border",  enabled = true, speed = 8, bezier = "easeOutQuint" })

-- слои: панель, лаунчер, уведомления
hl.layer_rule({ match = { namespace = "waybar" },       animation = "slide top" })
hl.layer_rule({ match = { namespace = "launcher" },     animation = "popin 90%" })
hl.layer_rule({ match = { namespace = "swaync-.*" },    animation = "slide right" })

-- внешний вид
hl.config({
  general = {
    border_size = 2,
    col = { active_border = { colors = { "rgba(c4c4c6ff)", "rgba(4a4a4eff)" }, angle = 45 } },
  },
  decoration = {
    rounding = 16,
    rounding_power = 3,
    dim_inactive = true,
    dim_strength = 0.1,
  },
})

hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))


hl.bind(mod .. " + W", hl.dsp.exec_cmd("quickshell ipc call widgets toggle"))

hl.on("hyprland.start", function()
  -- в VM нужен программный рендер; на реальной машине убери "env QT_QUICK_BACKEND=software"
end)

hl.bind(mod .. " + N", hl.dsp.exec_cmd("quickshell ipc call quicksettings toggle"))
hl.layer_rule({ match = { namespace = "quick-settings" }, blur = true, ignore_alpha = 0.3 })

hl.define_submap("widgets", function()
  hl.bind(mod .. " + W", hl.dsp.exec_cmd("quickshell ipc call widgets toggle"))
  hl.bind(mod .. " + SHIFT + R", hl.dsp.submap("reset"))
end)

hl.on("hyprland.start", function()
  hl.exec_cmd('touch "$XDG_RUNTIME_DIR/shader-off"')
end)

hl.config({ misc = { allow_session_lock_restore = true } })

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function()
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

hl.bind("Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh region"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh full"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh edit"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh region"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("$HOME/.local/bin/clip.sh"))

hl.layer_rule({ match = { namespace = "osd" }, blur = true, ignore_alpha = 0.3 })

hl.on("hyprland.start", function()
  hl.exec_cmd("$HOME/.local/bin/theme wall apply")
end)

hl.bind(mod .. " + A", hl.dsp.exec_cmd("quickshell ipc call player toggle"))
hl.layer_rule({ match = { namespace = "player" }, blur = true, ignore_alpha = 0.3 })

hl.bind(mod .. " + slash", hl.dsp.exec_cmd("quickshell ipc call cheatsheet toggle"))
hl.bind(mod .. " + F1", hl.dsp.exec_cmd("quickshell ipc call cheatsheet toggle"))
hl.layer_rule({ match = { namespace = "cheatsheet" }, blur = true, ignore_alpha = 0.3 })

hl.bind(mod .. " + O", hl.dsp.exec_cmd("quickshell ipc call notes toggle"))

hl.layer_rule({ match = { namespace = "notes" }, blur = true, ignore_alpha = 0.3 })

hl.bind(mod .. " + D", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))
hl.layer_rule({ match = { namespace = "qs-launcher" }, blur = true, ignore_alpha = 0.3 })

hl.on("hyprland.start", function()
  hl.exec_cmd("$HOME/.local/bin/rice up")
end)

hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("$HOME/.local/bin/perf toggle"))
