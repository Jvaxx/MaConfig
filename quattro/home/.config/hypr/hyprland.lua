-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Scratchpad (SUPER+S) uses the scrolling layout too. Numeric workspaces are
-- handled by the SUPER+ALT+L toggle's state files in
-- ~/.local/state/omarchy/workspace-layouts/; special workspaces aren't, so the
-- rule lives here.
hl.workspace_rule({ workspace = "special:scratchpad", layout = "scrolling" })

-- Games keep simulating when off-screen.
-- On Wayland a hidden window stops getting frame callbacks, so its render loop
-- blocks in swapbuffers. Factorio updates and renders on the same thread, so a
-- blocked present freezes/slows the simulation. render_unfocused makes Hyprland
-- keep feeding frame events to the window while it isn't visible.
hl.config({
    misc = {
        render_unfocused_fps = 60, -- default 15
    },
})

o.window({ class = "^(factorio)$" }, { render_unfocused = true })
