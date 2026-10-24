-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print
--
-- Same bindings as Quattro (quattro/home/.config/hypr/bindings.lua), on the
-- built-in French Mac keyboard (see hypr/input.lua):
--   - SUPER is Cmd and ALT is the LEFT Option key (right Option is AltGr).
--     Modifier names don't lie here: Quattro needs altwin:swap_lalt_lwin to get
--     the Ctrl, Alt, Super, Space order this keyboard has natively, so every
--     binding below sits on the same physical keys as on Quattro.
--   - The layout is fr(mac), the one Quattro's frmac imitates, so keysyms and
--     keycodes name the keys printed on the board.
-- Left out from Quattro: the keyboard layout toggle (one layout here) and the
-- Bbox remote dictation (that remote pairs with the desktop).

-- --- Perplexity web app ----------------------------------------------------
-- Stock Omarchy puts ChatGPT on SUPER+SHIFT+A (see
-- $OMARCHY_PATH/default/hypr/bindings/applications.lua). Replaced with
-- Perplexity, launched as a Chromium --app window by omarchy-launch-webapp.
-- focus = false keeps it on plain omarchy-launch-webapp: every press opens a
-- new window rather than focusing an existing one.
hl.unbind("SUPER + SHIFT + A") -- was: ChatGPT
o.bind("SUPER + SHIFT + A", "Perplexity", { webapp = "https://www.perplexity.ai", focus = false })

-- --- Claude web app -------------------------------------------------------
-- Stock Omarchy puts the HEY calendar on SUPER+SHIFT+C (see
-- $OMARCHY_PATH/default/hypr/bindings/applications.lua). That bind is baked
-- into the Hyprland defaults, so removing the HEY web app from the menus left
-- the key still pointing at app.hey.com -- it has to be unbound here.
-- Claude runs as a Chromium --app window via omarchy-launch-webapp, matching
-- the "Claude" launcher created with `omarchy webapp install`.
-- focus = false keeps it on plain omarchy-launch-webapp: every press opens a
-- new window rather than focusing an existing one (same as Perplexity below).
hl.unbind("SUPER + SHIFT + C") -- was: Calendar (app.hey.com)
o.bind("SUPER + SHIFT + C", "Claude", { webapp = "https://claude.ai", focus = false })

-- --- Keybindings menu on Super + "?" ----------------------------------------
-- code:58 is <AB07>, the key printed ", ?" right of N. On Quattro it is the
-- physical M key of the QWERTY board, where frmac puts , and ?: same symbol,
-- same binding. Bound by keycode, as on Quattro.
-- This displaces Omarchy's SUPER + comma (dismiss last notification), which
-- lands on that very same physical key under fr(mac). Dismiss-all survives on
-- SUPER+SHIFT+comma, and the notification history on SUPER+SHIFT+ALT+comma.
hl.unbind("SUPER + K") -- was: Keybindings menu
hl.unbind("SUPER + comma") -- was: Dismiss last notification
o.bind("SUPER + code:58", "Show key bindings", "omarchy-menu-keybindings")

-- --- Vim-style focus movement -----------------------------------------------
-- Twin of Omarchy's SUPER + arrows. h/j/k/l are <AC06>-<AC09>, the same physical
-- keys in AZERTY and QWERTY.
-- Moving windows stays on SUPER+SHIFT + arrows (swap window), untouched.
-- SUPER + H is unbound in Quattro; SUPER + K was released just above.
hl.unbind("SUPER + J") -- was: Toggle window split
hl.unbind("SUPER + L") -- was: Toggle workspace layout
o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Relocated Omarchy defaults, displaced by the four binds above.
o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- --- Scrolling layout: the vertical dimension -------------------------------
-- Only meaningful on a workspace using the scrolling layout (SUPER+ALT+L
-- toggles it); on dwindle these are silently ignored.
--
-- The scrolling layout is a one-dimensional tape of columns -- scrolling:direction
-- picks the axis ("right" by default). The perpendicular axis is not a second
-- scroll: a column simply splits its windows across the screen height, so two
-- windows in one column are 782px tall each instead of 1576.
--
-- consume_or_expel is adaptive: it CONSUMES the window into the neighbouring
-- column when the window is alone in its own column, and EXPELS it back out to
-- a dedicated column when it is sharing one. So the same key stacks and unstacks.
--
-- SHIFT is the "restructure the window" modifier here, matching SUPER+SHIFT+arrows
-- (swap window), while plain SUPER+H/J/K/L keeps moving focus -- including up and
-- down between windows already stacked inside a column.
o.bind("SUPER + SHIFT + H", "Stack window into column on the left", hl.dsp.layout("consume_or_expel prev"))
o.bind("SUPER + SHIFT + L", "Stack window into column on the right", hl.dsp.layout("consume_or_expel next"))

-- --- Scrolling layout: column width / "full screen" -------------------------
-- Stock SUPER+CTRL+F ("Tiled full screen") only flips the window's CLIENT
-- fullscreen state (fullscreenstate 0 2), which asks the app to drop its own
-- chrome but never resizes the tile. On dwindle that pairs with a big tile; on
-- the scrolling layout the column keeps its width, so the key looks dead. Left
-- unbound here -- widening lives on SUPER+ALT+F with the rest of the window ops.
hl.unbind("SUPER + CTRL + F") -- was: Tiled full screen (a no-op on scrolling)

-- The scrolling way to "go full screen" is simply a column of width 1.0: the
-- window still sits on the tape, so SUPER+H/L keep scrolling focus to the
-- neighbours (unlike SUPER+F, which lifts it out of the layout entirely).
-- colresize +conf cycles scrolling:explicit_column_widths, which defaults to
-- 0.333, 0.5, 0.667, 1.0 and wraps -- full width is just the last stop.
--
-- Stock SUPER+ALT+F is fullscreen mode 1 (maximize), which is useful on dwindle
-- but broken on scrolling: it pushes the neighbouring columns fully offscreen
-- and a following movefocus lands on no window at all. So the bind dispatches
-- per layout instead of picking one and breaking the other.
hl.unbind("SUPER + ALT + F") -- was: Full width (maximize; kept for dwindle)
o.bind("SUPER + ALT + F", "Full width / cycle column width", "hypr-window-full-width")

-- --- Save/restore window width ----------------------------------------------
-- Omarchy puts these on SUPER + (ALT +) Home. Quattro's MAD68 has no Home key,
-- and neither has this keyboard (Home is Fn + Left), so the same move applies.
-- D as in "dimension"; SUPER + D / SUPER + ALT + D were both unbound in stock
-- Omarchy.
--
-- Note this saves WIDTH only, keyed by window class + workspace, into
-- ~/.local/state/omarchy/windows/. On the scrolling layout there is no position
-- to save (a column's place is just where it sits on the tape) and height is
-- divided evenly between the windows sharing a column.
hl.unbind("SUPER + ALT + Home") -- was: Save window width
hl.unbind("SUPER + Home") -- was: Restore window width
o.bind("SUPER + ALT + D", "Save window width", "omarchy-hyprland-window-width save")
o.bind("SUPER + D", "Restore window width", "omarchy-hyprland-window-width restore")

-- --- Shazam: identify the song playing on the speakers ----------------------
-- ~/.local/bin/omarchy-shazam records ~8s from the monitor source of the
-- default sink (what you hear, not the mic) and asks Shazam's servers, via
-- songrec. Result lands in a notification and on the clipboard.
--
-- code:38 is <AC01>, the key printed Q -- "q" as in the Shazam key, the same
-- physical key as on Quattro. Plain SUPER on that key was free in stock
-- Omarchy; SUPER+CTRL+Q keeps its default meaning.
o.bind("SUPER + code:38", "Identify song playing (Shazam)", "omarchy-shazam")
