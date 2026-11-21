-- Оформление и привязки райса: одна согласованная конфигурация.
-- Цвета рамок и тени потом переопределяет theme.lua (его генерирует команда theme).
-- Остальные привязки (SUPER+Q/C/V/M, рабочие столы, мышь) берутся из стандартного hyprland.lua.
local mod = "SUPER"

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 12,
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(c4c4c6ff)", "rgba(4a4a4eff)" }, angle = 45 },
      inactive_border = "rgba(1c1c1eff)",
    },
  },
  decoration = {
    rounding = 16,
    rounding_power = 3,
    active_opacity = 0.96,
    inactive_opacity = 0.88,
    dim_inactive = true,
    dim_strength = 0.1,
    shadow = { enabled = true, range = 24, render_power = 3, color = "rgba(00000099)" },
    blur = { enabled = true, size = 8, passes = 3, noise = 0.06, vibrancy = 0.1 },
  },
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    allow_session_lock_restore = true,
  },
})

-- анимации
hl.curve("soft", { type = "spring", mass = 1, stiffness = 90, dampening = 14 })

hl.animation({ leaf = "windowsIn",           enabled = true, speed = 4, spring = "soft", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 85%" })
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 4, spring = "soft" })
hl.animation({ leaf = "fade",                enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "border",              enabled = true, speed = 8, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesIn",        enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesOut",       enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefadevert -50%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefadevert -50%" })

-- слои: размытие и анимация появления (namespace совпадают с WlrLayershell.namespace в Quickshell)
hl.layer_rule({ match = { namespace = "waybar" },         blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "swaync-.*" },      blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "qs-launcher" },    blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "quick-settings" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "osd" },            blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "player" },         blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "cheatsheet" },     blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "notes" },          blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "waybar" },         animation = "slide top" })
hl.layer_rule({ match = { namespace = "swaync-.*" },      animation = "slide right" })

-- окна
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- приложения и оверлеи (полный список: SUPER+/)
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("quickshell ipc call widgets toggle"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("quickshell ipc call quicksettings toggle"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("quickshell ipc call player toggle"))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("quickshell ipc call notes toggle"))
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("quickshell ipc call cheatsheet toggle"))
hl.bind(mod .. " + F1",    hl.dsp.exec_cmd("quickshell ipc call cheatsheet toggle"))

-- громкость и яркость с плашкой на экране (Quickshell OSD).
-- Клавиши Fn+F1 (без звука), Fn+F2/F3 (тише/громче), Fn+F5/F6 (яркость) ноутбук отдаёт как XF86-клавиши.
-- Стандартные привязки из hyprland.lua меняют громкость без плашки: сначала снимаем их, иначе шаг сработает дважды.
-- hl.unbind снимает привязки, объявленные ДО него, поэтому monochrome подключается в конце hyprland.lua.
for _, key in ipairs({ "XF86AudioMute", "XF86AudioLowerVolume", "XF86AudioRaiseVolume", "XF86MonBrightnessDown", "XF86MonBrightnessUp" }) do
  hl.unbind(key)
end
local osd = "bash $HOME/.config/quickshell/scripts/osd.sh "
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(osd .. "mute"),    { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(osd .. "voldown"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(osd .. "volup"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osd .. "bridown"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(osd .. "briup"),   { locked = true, repeating = true })
-- то же самое обычными клавишами, для виртуальной машины: окно ВМ часто не получает Fn-клавиши
hl.bind(mod .. " + SHIFT + F1", hl.dsp.exec_cmd(osd .. "mute"))
hl.bind(mod .. " + SHIFT + F2", hl.dsp.exec_cmd(osd .. "voldown"), { repeating = true })
hl.bind(mod .. " + SHIFT + F3", hl.dsp.exec_cmd(osd .. "volup"),   { repeating = true })
hl.bind(mod .. " + SHIFT + F5", hl.dsp.exec_cmd(osd .. "bridown"), { repeating = true })
hl.bind(mod .. " + SHIFT + F6", hl.dsp.exec_cmd(osd .. "briup"),   { repeating = true })

-- скриншоты, буфер обмена, лёгкий режим
hl.bind("Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh region"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh full"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh edit"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("$HOME/.local/bin/shot.sh region"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("$HOME/.local/bin/clip.sh"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("$HOME/.local/bin/perf toggle"))

-- режим, пока открыт оверлей виджетов (входит и выходит Quickshell)
hl.define_submap("widgets", function()
  hl.bind(mod .. " + W", hl.dsp.exec_cmd("quickshell ipc call widgets toggle"))
  hl.bind(mod .. " + SHIFT + R", hl.dsp.submap("reset"))
end)

-- запуск сессии: один обработчик
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
  -- история буфера работает только при установленном cliphist
  hl.exec_cmd("sh -c 'command -v cliphist >/dev/null 2>&1 && exec wl-paste --type text --watch cliphist store'")
  hl.exec_cmd("sh -c 'command -v cliphist >/dev/null 2>&1 && exec wl-paste --type image --watch cliphist store'")
  hl.exec_cmd("$HOME/.local/bin/theme wall apply")
  hl.exec_cmd("$HOME/.local/bin/rice up")
end)
