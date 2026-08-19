-- Keep only your personal input overrides here. Settings below replace
-- Omarchy's defaults (default/hypr/input.lua).

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
--
-- Custom layouts from ~/.config/xkb/symbols/{frmac,qwertyansi}, for a MAD68:
-- QWERTY ANSI, 65%, no F-row, no <LSGT> key, driven as French (Macintosh).
--
-- frmac MUST stay at index 0: omarchy-system-lock runs
-- `hyprctl switchxkblayout all 0`, so index 0 is what you get after unlocking.
-- Hyprland also resolves keybindings against index 0 only.
--
-- Never add grp:alts_toggle here (Omarchy suggests it in a commented example).
-- It redefines <RALT> to Alt_R/ISO_Next_Group, overriding level3(ralt_switch)
-- and killing AltGr -- taking @ # ` ~ EUR {} [] \ | and the custom <> with it.
-- AltGr is the only route to @ # ` ~ on this board. It also fights
-- altwin:swap_lalt_lwin over <LALT>. Layouts toggle on CTRL+SHIFT+SPACE
-- instead; see hypr/bindings.lua.
--
-- caps:escape_shifted_capslock -> CapsLock is a second Escape (the top-left key
--                                 is a real Escape too), and Shift+CapsLock is
--                                 a real Caps Lock.
-- altwin:swap_lalt_lwin        -> bottom row reads Ctrl, Alt, Super, Space.
--
-- This replaces Quattro's default `compose:caps,shift:both_capslock_cancel`:
-- Caps is Escape here, so there is no Compose key and ~/.XCompose is unused
-- (emoji are on SUPER+CTRL+E; fr(mac) has real dead keys for accents).
-- Verify a change to any of the three lines below with:
--   xkbcli compile-keymap --layout frmac,qwertyansi --variant ansi,ansi \
--       --options caps:escape_shifted_capslock,altwin:swap_lalt_lwin
hl.config({
  input = {
    kb_layout = "frmac,qwertyansi",
    kb_variant = "ansi,ansi",
    kb_options = "caps:escape_shifted_capslock,altwin:swap_lalt_lwin",

    -- Change speed of keyboard repeat (Omarchy defaults: 40 / 250).
    repeat_rate = 60,
    repeat_delay = 170,
  },
})

-- Omarchy's defaults already cover the rest of the old input.conf:
-- numlock_by_default, touchpad clickfinger_behavior, touchpad scroll_factor 0.4,
-- and the (Alacritty|kitty|foot) / ghostty scroll_touchpad window rules.
-- They are left to the defaults rather than repeated here.
