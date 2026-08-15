# TimeTracker

An Omarchy shell bar widget for tracking time against a list of tasks. The bar
shows the combined total of every task; clicking it opens the task list.

## Install

The plugin lives in the user plugin directory, so a copy of this folder is all
that's needed:

```bash
mkdir -p ~/.config/omarchy/plugins/time-tracker
# copy Panel.qml, TaskModel.js, and manifest.json into that directory
```

Then add it to the bar — either with the command:

```bash
omarchy bar put time-tracker --section center
```

or by adding an entry to `bar.layout` in `~/.config/omarchy/shell.json`:

```json

{ "id": "time-tracker" }
```


If you want to place it on the right, use this command:

```bash
omarchy bar move time-tracker --section right
```

Saving anything under `~/.config/omarchy/plugins/` reloads plugin code
automatically; `shell.json` hot-reloads too.

## Using it

- **Bar button** — the running total of every task. It switches to the bar's
  active color while at least one timer is going.
- **Task row** — status dot, title, elapsed time, and a `>` chevron.
  - Click the **task name** to start/stop that task's timer.
  - Click the **chevron** to reveal that row's actions.
- **Row actions** — play/pause (start or stop the timer), reset (set this
  task back to `00:00:00`, leaving a running timer running), edit, delete.
- **Edit mode** — the title and the time both become input fields. `Enter`
  commits, `Esc` or the `✕` button cancels, `Tab` jumps from title to time.
  The time field accepts `HH:MM:SS`, `MM:SS`, a bare number of seconds, or a
  suffixed form like `1h30m`. Unparseable input leaves the stored time alone.
- **Footer buttons** — the `+` appends a new task titled "Empty", ready to be
  edited. The reset button to its left zeroes *every* task at once; like the
  per-row reset, any running timer keeps running from `00:00:00`. It takes
  effect immediately, with no confirmation prompt.
- Running timers render in the full foreground color; idle ones are dimmed, so
  the active tasks stand out.

Multiple timers can run at once — nothing stops the previous one when you
start another.

## Keyboard

The popup is fully keyboard-navigable.

| Key | Action |
| --- | --- |
| `j` / `↓` | Move the cursor down — or into an expanded row's actions |
| `k` / `↑` | Move the cursor up — or back out of the actions onto the row |
| `l` / `→` | Expand the cursor row's actions, then walk them rightwards |
| `h` / `←` | Walk the actions leftwards; from the first one, collapse the row |
| `Enter` / `Space` | Run the focused action, or start/stop the cursor task's timer |
| `e` | Edit the cursor task |
| `r` | Reset the cursor task to `00:00:00` |
| `d` / `x` | Delete the cursor task |
| `a` / `n` | Add a new task |
| `Tab` | Move to the next bar panel |
| `Esc` | Close the popup |

## Data

Tasks persist to `~/.config/omarchy/time-tracker.json` (override with the
`dataPath` setting on the widget's `shell.json` entry). A running task stores
the epoch-ms stamp of when it started alongside its banked seconds, so timers
keep counting correctly across a shell restart.

The file is watched, so hand-edits (and edits from other shell instances) are
picked up immediately without a reload.

## Multiple monitors

The bar widget is instantiated once per monitor, and each instance keeps its own
copy of the task list. They stay in sync through the data file: every mutation is
written out, and the other instances reload on the change — so starting a timer
on one monitor starts it on all of them. Only the shared task state syncs; the
popup, keyboard cursor, and in-progress edit stay local to the monitor you're
using.

## IPC

```bash
omarchy-shell time-tracker open     # or close / show / hide / toggle
omarchy-shell time-tracker add      # append a new "Empty" task
omarchy-shell time-tracker resetAll # zero every task's timer
omarchy-shell time-tracker total    # print the combined total
```

## License

MIT
