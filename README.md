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
- **`+` button** — appends a new task titled "Empty", ready to be edited.
- Running timers render in the full foreground color; idle ones are dimmed, so
  the active tasks stand out.

Multiple timers can run at once — nothing stops the previous one when you
start another.

## Keyboard

The popup is fully keyboard-navigable.

| Key | Action |
| --- | --- |
| `j` / `↓` | Move the cursor down |
| `k` / `↑` | Move the cursor up |
| `l` / `→` | Expand the cursor row's actions |
| `h` / `←` | Collapse the cursor row |
| `Enter` / `Space` | Start/stop the cursor task's timer |
| `e` | Edit the cursor task |
| `r` | Reset the cursor task to `00:00:00` |
| `a` / `n` | Add a new task |
| `x` | Delete the cursor task |
| `Tab` | Move to the next bar panel |
| `Esc` | Close the popup |

## Data

Tasks persist to `~/.config/omarchy/time-tracker.json` (override with the
`dataPath` setting on the widget's `shell.json` entry). A running task stores
the epoch-ms stamp of when it started alongside its banked seconds, so timers
keep counting correctly across a shell restart.

The file is only read at load time, so hand-edits need a reload —
`omarchy restart shell` or `omarchy-shell shell rescanPlugins`.

## IPC

```bash
omarchy-shell time-tracker open     # or close / show / hide / toggle
omarchy-shell time-tracker add      # append a new "Empty" task
omarchy-shell time-tracker total    # print the combined total
```

## License

MIT
