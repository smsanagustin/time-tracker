# TimeTracker

An Omarchy shell bar widget for tracking time against a list of tasks based on this Gnome [extension](https://github.com/aliakseiz/tracker). The bar
shows the combined total of every task; clicking it opens the task list.

**Note:** This plugin is vibe-coded with Claude Opus 5. Use with caution.

## Screenshot
<img width="454" height="185" alt="image" src="https://github.com/user-attachments/assets/514e26c1-3306-4634-988f-fbe2fd542d88" />


## Install

The plugin lives in the user plugin directory, to install:
```
omarchy plugin add https://github.com/smsanagustin/time-tracker --enable
```


Saving anything under `~/.config/omarchy/plugins/` reloads plugin code
automatically; `shell.json` hot-reloads too.

## Uninstall or remove the plugin
To remove the plugin from your shell, run:
```
omarchy plugin remove sophie.time-tracker
```

## How to use

- **Bar button** — Shows the total time of all tasks. Color changes to red when at least one timer is running.
- **Task timer** - For each task you can: start/stop timer, edit task, reset timer or delete the task.

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
| `?` | Toggle the keybind cheat sheet |
| `Esc` | Close the cheat sheet if open, otherwise the popup |

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
