-- Keep only your personal input overrides here. Settings below replace
-- Omarchy's defaults (default/hypr/input.lua).

-- Keyboard: the built-in French Mac (AZERTY, ISO) keyboard.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
--
-- Quattro needs custom xkb layouts (frmac, qwertyansi) and
-- altwin:swap_lalt_lwin to make a QWERTY PC board behave like this one. Here
-- fr(mac) already is the target, so none of that applies:
--   - the left of the bottom row reads Ctrl, Option (Alt), Cmd (Super),
--     Space -- the order Quattro gets from swap_lalt_lwin -- so Quattro's
--     bindings land on the same physical keys;
--   - left Option is Alt_L (Mod1), so SUPER+ALT bindings use it.
-- With a single layout there is no layout toggle (Quattro's CTRL+SHIFT+SPACE
-- and kb-layout-toggle are not carried over).
--
-- frmacbook (~/.config/xkb/symbols/frmacbook) is fr(mac) with two changes:
--   - right Cmd is AltGr (@ # { } [ ] | \ ~) and right Option is Super;
--   - the key under Escape types @ # and the key right of Left Shift < >,
--     as printed (the kernel reports the two the wrong way round).
-- Fn <-> left Ctrl cannot be done here: Fn is evdev KEY_FN (464), past the
-- 255 keycode ceiling xkb can represent. Only hid_apple's swap_fn_leftctrl
-- can swap it.
--
-- caps:escape_shifted_capslock -> Caps Lock is a second Escape, and
--                                 Shift+Caps Lock is a real Caps Lock (as on
--                                 Quattro).
-- Verify a change with:
--   xkbcli compile-keymap --layout frmacbook --options caps:escape_shifted_capslock
hl.config({
  input = {
    kb_layout = "frmacbook",
    kb_variant = "",
    kb_options = "caps:escape_shifted_capslock",

    -- Change speed of keyboard repeat (Omarchy defaults: 40 / 250).
    repeat_rate = 60,
    repeat_delay = 170,
  },
})

-- Touchpad, macOS style (2026-10-24).
-- Omarchy turns tap_to_click off because of stray taps while typing on the
-- Asahi touchpad; we re-enable it and keep disable_while_typing on.
hl.config({
  input = {
    touchpad = {
      tap_to_click = true,          -- 1 finger = left, 2 = right, 3 = middle
      drag_3fg = 1,                 -- three-finger drag (libinput >= 1.28)
      disable_while_typing = true,
    },
  },
})

-- Three fingers are taken by drag, so switch workspaces with four (as macOS
-- does when three-finger drag is on).
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Omarchy's defaults already cover the rest: numlock_by_default, touchpad
-- clickfinger_behavior and scroll_factor 0.4, and the per-terminal
-- scroll_touchpad window rules.
