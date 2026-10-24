# math-render

Draws LaTeX in Claude Code's assistant replies as images in the terminal.
It's a port of [pi-math](https://github.com/monotykamary/pi-math) (MIT, see
`LICENSE.pi-math`): the same scanner, MathJax → SVG → Resvg PNG pipeline and
sizing rules.

- `$…$` / `\(…\)` inside a sentence: a one-row inline image that wraps with the text.
- `$$…$$`, `\[…\]`, `equation`/`align`/`gather`/… environments, or a formula alone
  on its line: a centered display image.
- Code spans, code blocks, currency (`$5`) and tables are left alone; a formula
  that does not parse stays as written.

Images need a terminal with the kitty graphics protocol (Ghostty, kitty).
Elsewhere, and through tmux, the LaTeX source is shown instead.

## How it works

`hooks/register.tsx` redraws `AssistantMessage` rows that contain a complete
formula. It starts `helper/server.ts` (Node ≥ 23, run directly) on a Unix
socket per session, because MathJax and Resvg need Node. The helper reads
the terminal's cell size from its tty and the text color from your Ghostty
or kitty config.

## Commands and settings

`/math-render on|off|status|clear`

| Variable | Effect |
| --- | --- |
| `CLAUDE_MATH_COLOR` | Formula color, `#rrggbb` (default: terminal foreground) |
| `CLAUDE_MATH_CELL` | Cell size in px, `WxH`, when it can't be detected |
| `CLAUDE_MATH_MACROS` / `CLAUDE_MATH_ENVIRONMENTS` | JSON TeX macro/environment definitions |
| `CLAUDE_MATH_FONT_FILES` / `CLAUDE_MATH_SYSTEM_FONTS` | Fonts for `\text{}` with non-Latin text |

After moving the folder, run `npm install` in `helper/`.
