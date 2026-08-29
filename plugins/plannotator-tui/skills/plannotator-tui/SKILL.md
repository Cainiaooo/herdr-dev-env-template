---
name: plannotator-tui
description: Open a Markdown plan or document for the human to review and annotate in a Herdr pane; their feedback arrives as your next message. Use when you have written a plan, spec, or design document that needs human review before you act on it.
---

# plannotator-tui: hand a document to the human for review

Only when `HERDR_ENV=1` (you are running inside Herdr). Otherwise tell the human where the
file is and ask them to review it, or use `plannotator annotate <file>` (Chrome) if they
want the browser review.

1. Write the document to a file. Do not paste it into chat as well.
2. Open it for review, from your own pane:

   ```powershell
   plannotator-tui herdr open docs/plans/auth.md
   ```

   plannotator-tui opens beside you (or as an overlay), already knowing that feedback
   comes back to this pane.
3. **End your turn.** Do not wait, poll, or read the pane. The review arrives as the next
   user message, as numbered feedback:

   ```
   ## 1. (line 12) Feedback on: "Rotate the token on every…"
   > Rotation on every privilege change will log people out…
   ```

   Address every item, then continue.

When you list files you want the human to open, print them as `file://` hyperlinks (OSC 8)
so Ctrl-click in Herdr opens them in plannotator-tui. PowerShell:

```powershell
$path = (Resolve-Path "docs/plans/auth.md").Path
$uri = ([Uri]$path).AbsoluteUri
Write-Host "`e]8;;$uri`e\docs/plans/auth.md`e]8;;`e\"
```

If `plannotator-tui` is not on `PATH`, the raw Herdr command is:

```powershell
herdr plugin pane open --plugin plannotator-tui --entrypoint doc --placement overlay --focus --cwd $PWD --env "PLANNOTATOR_TUI_FILE=$PWD\docs\plans\auth.md" --env "PLANNOTATOR_TUI_DELIVER_TO=$env:HERDR_PANE_ID"
```
