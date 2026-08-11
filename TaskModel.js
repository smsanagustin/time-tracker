// Pure helpers for TimeTracker. Kept free of QML types so the logic stays
// testable and the Panel only deals with wiring.

function pad2(value) {
  var n = Math.max(0, Math.floor(Number(value) || 0))
  return n < 10 ? "0" + n : String(n)
}

// Seconds -> "HH:MM:SS". Hours are not capped at 24; a task tracked for two
// days should read 48:xx:xx rather than wrapping back to zero.
function formatDuration(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  return pad2(hours) + ":" + pad2(minutes) + ":" + pad2(total % 60)
}

// Parses what the inline time editor accepts: "HH:MM:SS", "MM:SS", "SS",
// or a suffixed form like "1h30m" / "45m" / "90s". Returns null when the
// text isn't a duration so the caller can keep the field open instead of
// silently writing a zero.
function parseDuration(text) {
  var raw = String(text === undefined || text === null ? "" : text).trim()
  if (raw === "") return null

  if (raw.indexOf(":") !== -1) {
    var parts = raw.split(":")
    if (parts.length > 3) return null
    var seconds = 0
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i].trim()
      if (!/^\d+$/.test(part)) return null
      seconds = seconds * 60 + parseInt(part, 10)
    }
    return seconds
  }

  var suffixed = raw.match(/^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?\s*(?:(\d+)\s*s)?$/i)
  if (suffixed && (suffixed[1] || suffixed[2] || suffixed[3])) {
    return (parseInt(suffixed[1] || 0, 10) * 3600)
      + (parseInt(suffixed[2] || 0, 10) * 60)
      + parseInt(suffixed[3] || 0, 10)
  }

  if (/^\d+$/.test(raw)) return parseInt(raw, 10)
  return null
}

// A running task's displayed time is its stored total plus the wall-clock
// span since it was started. Storing `startedAt` (rather than only ticking
// `seconds`) is what lets a timer survive a shell restart mid-run.
function elapsedSeconds(task, nowMs) {
  if (!task) return 0
  var base = Math.max(0, Math.floor(Number(task.seconds) || 0))
  if (!task.running) return base
  var startedAt = Number(task.startedAt) || 0
  if (startedAt <= 0) return base
  return base + Math.max(0, Math.floor((nowMs - startedAt) / 1000))
}

function totalSeconds(tasks, nowMs) {
  if (!Array.isArray(tasks)) return 0
  var sum = 0
  for (var i = 0; i < tasks.length; i++) sum += elapsedSeconds(tasks[i], nowMs)
  return sum
}

function runningCount(tasks) {
  if (!Array.isArray(tasks)) return 0
  var count = 0
  for (var i = 0; i < tasks.length; i++) if (tasks[i] && tasks[i].running) count++
  return count
}

function indexOfId(tasks, id) {
  if (!Array.isArray(tasks)) return -1
  for (var i = 0; i < tasks.length; i++) if (tasks[i] && tasks[i].id === id) return i
  return -1
}

function sanitizeTitle(title) {
  return String(title === undefined || title === null ? "" : title)
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim()
}

function makeId(seed) {
  return "t" + Math.floor(seed) + "-" + Math.floor(Math.random() * 100000)
}

function normalizeTask(entry, seed) {
  if (!entry || typeof entry !== "object") return null
  var title = sanitizeTitle(entry.title)
  var seconds = Math.max(0, Math.floor(Number(entry.seconds) || 0))
  var running = entry.running === true
  var startedAt = Math.max(0, Math.floor(Number(entry.startedAt) || 0))
  // A persisted `running: true` with no start stamp can't be resumed
  // accurately; treat it as stopped rather than counting from the epoch.
  if (running && startedAt <= 0) running = false
  return {
    id: entry.id ? String(entry.id) : makeId(seed),
    title: title === "" ? "Empty" : title,
    seconds: seconds,
    running: running,
    startedAt: running ? startedAt : 0
  }
}

// Reads the on-disk payload. Accepts both the current `{ tasks: [...] }`
// shape and a bare array so a hand-edited file stays usable.
function parseState(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw).trim()
  if (text === "") return []
  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (error) {
    return []
  }
  var list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.tasks) ? parsed.tasks : [])
  var tasks = []
  for (var i = 0; i < list.length; i++) {
    var task = normalizeTask(list[i], i + 1)
    if (task) tasks.push(task)
  }
  return tasks
}

function serialize(tasks) {
  return JSON.stringify({ version: 1, tasks: Array.isArray(tasks) ? tasks : [] }, null, 2) + "\n"
}
