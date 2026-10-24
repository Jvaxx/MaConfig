# Git commit messages

- Format: a subject line (≤ 72 characters, no trailing period), then **one blank
  line**, then the body wrapped at ~72 columns. No Claude co-author or
  "Generated with Claude Code" lines in commits or PRs.
  Without the blank line git treats the whole message as the subject.
- Write the message to a file (heredoc) and commit with `git commit -F <file>`.
- Before pushing, check it: `git log -1 --format='[%s]%n---%n%b'` — the brackets
  must hold the subject alone. Fix with `git commit --amend -F <file>` while the
  commit is still unpushed; never amend or force-push a pushed commit unasked.

@~/.claude/pi.md
