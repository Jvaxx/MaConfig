-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- HDMI-A-1  ASUS VG28UQL1A  3840x2160@119.88  scale 1.6 -> 2400x1350 logical
-- HDMI-A-2  ASUS VX229      1920x1080@60      scale 1   -> 1920x1080 logical
--
-- The 4K sits on the left, so the 1080p starts at x=2400 (the 4K's *logical*
-- width, not 3840 -- positions are in logical pixels). The scale must divide
-- the panel into whole pixels: 3840/1.6 = 2400 and 2160/1.6 = 1350 exactly,
-- otherwise Hyprland snaps to the nearest scale that does.
--
-- The 1080p is bottom-aligned with the 4K: y = 1350 - 1080 = 270. Their bottom
-- edges line up, so the cursor crosses between them along that shared edge.
-- For top-aligned use "2400x0", for vertically centred "2400x135".
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@119.88", position = "0x0", scale = 1.6 })
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60", position = "2400x270", scale = 1 })

-- One global GDK_SCALE cannot serve 1.6 and 1 at once. 1 leaves scaling to the
-- compositor instead of having GTK double everything on the 1080p panel.
hl.env("GDK_SCALE", "1")

-- Omarchy's generic catch-all is deliberately absent here. The stock file has
--   local omarchy_monitor_scale = "auto"
--   hl.monitor({ output = "", mode = "preferred", position = "auto", scale = ... })
-- and omarchy-hyprland-monitor-scaling (SUPER+SLASH / SUPER+ALT+SLASH) rewrites
-- exactly those two lines with sed to persist a scale change. With both monitors
-- pinned above, the explicit rules win at reload, so that rewrite would change
-- the file while the visible scale never moved. Neither sed branch matches this
-- file, so nothing is silently edited.
--
-- Consequence: the scaling keybind still applies live (via `hyprctl eval`) but
-- does not survive a reload -- change the scale here instead. An unlisted
-- monitor falls back to Hyprland's own default of preferred/auto/1.

-- Workspaces 1-2 live on the 4K, 3-4 on the 1080p, 5 is deliberately unbound so
-- it opens on whichever monitor has focus. default = true picks the workspace
-- each monitor shows when it first comes up.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-2", default = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-2" })
