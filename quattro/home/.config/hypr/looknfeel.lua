-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- Tighter gaps, thicker border (Omarchy defaults: 5 / 10 / 2).
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 3,
  },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- Omarchy's defaults run ~380ms, which reads as sluggish. Speed is in
-- deciseconds, so 1.0 = 100ms: still a motion cue, no perceptible wait.
-- The beziers named here are defined in Omarchy's default looknfeel.lua, which
-- hyprland.lua loads before this file. Only the window/border/fade curves are
-- retimed; the layer animations keep their defaults.
hl.animation({ leaf = "windows", enabled = true, speed = 1.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.0, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.0, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "border", enabled = true, speed = 1.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.0, bezier = "quick" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.0, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.0, bezier = "almostLinear" })

-- No animation at all when switching desktops. `workspaces` is already disabled
-- in Omarchy's defaults; pinned here so it stays off if that ever changes.
-- specialWorkspace (the scratchpad, SUPER+S) defaults to a 3.0 slidevert.
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = false })

-- To go further, replace everything above with:
--   hl.config({ animations = { enabled = false } })
