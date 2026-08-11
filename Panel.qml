import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
// qs.Ui comes last so its TextField shadows the Qt Quick Controls one.
import qs.Ui
import "TaskModel.js" as TaskModel

Panel {
  id: root
  moduleName: "time-tracker"
  ipcTarget: "time-tracker"
  // We own the IPC handler so `open`/`close` route through the overrides
  // below, which also tear down an in-progress inline edit.
  manageIpc: false

  // Task list, mirrored to disk on every mutation. Entries are plain objects:
  // { id, title, seconds, running, startedAt }. `seconds` is the banked total
  // and `startedAt` is the epoch-ms stamp of the current run, so a running
  // timer keeps counting across a shell restart.
  property var tasks: []
  property bool loaded: false

  // Wall clock for the running-task readouts. Ticked once a second, only
  // while something needs it.
  property real nowMs: Date.now()

  // Row the keyboard cursor is on. `cursorActive` stays false until the user
  // actually presses j/k so a freshly opened panel isn't pre-highlighted.
  property int cursorIndex: 0
  property bool cursorActive: false

  // At most one row is expanded (action buttons revealed) or in edit mode at
  // a time; both are tracked by task id so list reordering can't strand them.
  property string expandedId: ""
  property string editingId: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color mutedForeground: Qt.darker(contentForeground, 1.75)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real panelWidth: Style.space(420)

  readonly property int totalSeconds: TaskModel.totalSeconds(tasks, nowMs)
  readonly property int runningCount: TaskModel.runningCount(tasks)
  readonly property bool anyRunning: runningCount > 0
  readonly property string totalText: TaskModel.formatDuration(totalSeconds)

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string configuredPath: String(setting("dataPath", "~/.config/omarchy/time-tracker.json"))
  readonly property string dataFilePath: configuredPath.indexOf("~/") === 0
    ? home + configuredPath.slice(1)
    : configuredPath

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------- lifecycle

  function open() {
    root.nowMs = Date.now()
    root.controller.show()
  }

  function close() {
    root.cancelEdit()
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  // ------------------------------------------------------------ persistence

  function loadTasks(raw) {
    root.tasks = TaskModel.parseState(raw)
    root.loaded = true
    root.clampCursor()
    root.nowMs = Date.now()
  }

  function persist() {
    // Guard against writing an empty list over a real file if a mutation
    // somehow lands before the first load resolves.
    if (!root.loaded) return
    dataFile.setText(TaskModel.serialize(root.tasks))
  }

  function setTasks(next) {
    root.tasks = next
    root.clampCursor()
    root.persist()
  }

  // QML doesn't see in-place edits to a `var` array, so every mutation
  // rebuilds the list with a fresh copy of the affected task.
  function updateTask(id, changes) {
    var next = []
    for (var i = 0; i < root.tasks.length; i++) {
      var task = root.tasks[i]
      if (task.id !== id) {
        next.push(task)
        continue
      }
      var copy = {
        id: task.id,
        title: task.title,
        seconds: task.seconds,
        running: task.running,
        startedAt: task.startedAt
      }
      for (var key in changes) copy[key] = changes[key]
      next.push(copy)
    }
    root.setTasks(next)
  }

  // ----------------------------------------------------------- task actions

  function addTask() {
    var next = root.tasks.slice()
    var task = {
      id: TaskModel.makeId(Date.now()),
      title: "Empty",
      seconds: 0,
      running: false,
      startedAt: 0
    }
    next.push(task)
    root.setTasks(next)
    root.cursorIndex = next.length - 1
    root.cursorActive = true
    root.expandedId = ""
  }

  function removeTask(id) {
    var next = []
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].id !== id) next.push(root.tasks[i])
    }
    if (root.expandedId === id) root.expandedId = ""
    if (root.editingId === id) root.cancelEdit()
    root.setTasks(next)
  }

  function startTimer(id) {
    root.nowMs = Date.now()
    root.updateTask(id, { running: true, startedAt: root.nowMs })
  }

  function stopTimer(id) {
    var index = TaskModel.indexOfId(root.tasks, id)
    if (index < 0) return
    root.nowMs = Date.now()
    root.updateTask(id, {
      running: false,
      startedAt: 0,
      seconds: TaskModel.elapsedSeconds(root.tasks[index], root.nowMs)
    })
  }

  function toggleTimer(id) {
    var index = TaskModel.indexOfId(root.tasks, id)
    if (index < 0) return
    root.tasks[index].running ? root.stopTimer(id) : root.startTimer(id)
  }

  // "Reset", the second row action: zero the clock but leave a running timer
  // running — it simply starts counting again from 00:00:00.
  function resetTimer(id) {
    var index = TaskModel.indexOfId(root.tasks, id)
    if (index < 0) return
    root.nowMs = Date.now()
    root.updateTask(id, {
      seconds: 0,
      startedAt: root.tasks[index].running ? root.nowMs : 0
    })
  }

  // "Reset all", the footer action: zero every task's clock. Same rule as the
  // per-row reset — a running timer keeps running, just from 00:00:00.
  function resetAllTimers() {
    if (root.tasks.length === 0) return
    root.nowMs = Date.now()
    var next = []
    for (var i = 0; i < root.tasks.length; i++) {
      var task = root.tasks[i]
      next.push({
        id: task.id,
        title: task.title,
        seconds: 0,
        running: task.running,
        startedAt: task.running ? root.nowMs : 0
      })
    }
    root.setTasks(next)
  }

  function toggleTimerAt(index) {
    if (index < 0 || index >= root.tasks.length) return
    root.toggleTimer(root.tasks[index].id)
  }

  function toggleExpanded(id) {
    root.expandedId = root.expandedId === id ? "" : id
  }

  // ------------------------------------------------------------- edit mode

  function startEdit(id) {
    root.expandedId = ""
    root.editingId = id
    var index = TaskModel.indexOfId(root.tasks, id)
    if (index >= 0) {
      root.cursorIndex = index
      root.cursorActive = true
    }
  }

  function startEditAt(index) {
    if (index < 0 || index >= root.tasks.length) return
    root.startEdit(root.tasks[index].id)
  }

  function cancelEdit() {
    if (root.editingId === "") return
    root.editingId = ""
    root.refocusKeys()
  }

  // Commits the inline editor. An unparseable duration leaves the stored
  // time untouched rather than silently zeroing a tracked task.
  function commitEdit(id, titleText, timeText) {
    var index = TaskModel.indexOfId(root.tasks, id)
    if (index < 0) return root.cancelEdit()

    var title = TaskModel.sanitizeTitle(titleText)
    var parsed = TaskModel.parseDuration(timeText)
    var changes = { title: title === "" ? "Empty" : title }
    if (parsed !== null) {
      changes.seconds = parsed
      // Rebase a running timer so the edited value is the new starting point
      // instead of having the current run's elapsed time added back on top.
      if (root.tasks[index].running) {
        root.nowMs = Date.now()
        changes.startedAt = root.nowMs
      }
    }
    root.updateTask(id, changes)
    root.editingId = ""
    root.refocusKeys()
  }

  function refocusKeys() {
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  // -------------------------------------------------------------- keyboard

  function clampCursor() {
    if (root.tasks.length === 0) {
      root.cursorIndex = 0
      return
    }
    root.cursorIndex = Math.max(0, Math.min(root.cursorIndex, root.tasks.length - 1))
  }

  function moveCursor(dx, dy) {
    if (root.tasks.length === 0) return
    if (dy !== 0) {
      if (!root.cursorActive) {
        root.cursorActive = true
        if (dy > 0) return
      }
      root.cursorIndex = Math.max(0, Math.min(root.cursorIndex + dy, root.tasks.length - 1))
    }
    if (dx !== 0) {
      root.cursorActive = true
      var id = root.tasks[root.cursorIndex].id
      root.expandedId = dx > 0 ? id : (root.expandedId === id ? "" : root.expandedId)
    }
  }

  function handleTextKey(text) {
    var key = String(text || "").toLowerCase()
    if (key === "a" || key === "n") root.addTask()
    else if (key === "e") root.startEditAt(root.cursorIndex)
    else if (key === "r" && root.tasks.length > 0) root.resetTimer(root.tasks[root.cursorIndex].id)
  }

  function deleteCursorTask() {
    if (root.tasks.length === 0) return
    root.removeTask(root.tasks[root.cursorIndex].id)
  }

  // --------------------------------------------------------------- plumbing

  FileView {
    id: dataFile
    path: root.dataFilePath
    atomicWrites: true
    // Our own writes are the only expected source of change; watching would
    // just bounce every save back through the parser.
    watchChanges: false
    printErrors: false
    onLoaded: root.loadTasks(text())
    // First run: the file doesn't exist yet. Without this the panel would
    // never reach `loaded` and could never create it.
    onLoadFailed: root.loadTasks("")
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.anyRunning || root.opened
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: "time-tracker"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function add(): void { root.addTask() }
    function resetAll(): void { root.resetAllTimers() }
    function total(): string { return root.totalText }
  }

  Component.onCompleted: Qt.callLater(function() { dataFile.reload() })

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.totalText
    labelVisible: true
    hasVisualContent: true
    active: root.anyRunning
    tooltipText: root.anyRunning
      ? "Total " + root.totalText + " · " + root.runningCount + " running"
      : "Total " + root.totalText
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(root.panelWidth)
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The inline editor's text fields own every key while it is open.
      blocked: root.editingId !== ""

      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: {
        root.cursorActive = true
        root.toggleTimerAt(root.cursorIndex)
      }
      onDeleteRequested: root.deleteCursorTask()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { root.handleTextKey(t) }

      Column {
        id: contentColumn
        width: Math.max(1, keyCatcher.width)
        spacing: Style.space(8)

        ListView {
          id: taskList
          width: parent.width
          height: Math.min(contentHeight, Style.space(340))
          spacing: Style.space(2)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          visible: root.tasks.length > 0

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          model: root.tasks
          currentIndex: root.cursorIndex
          onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

          // ListView's delegate context doesn't reach into a nested
          // `component` declaration, so the wrapper forwards it explicitly.
          delegate: Item {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: taskRow.implicitHeight

            TaskRow {
              id: taskRow
              width: parent.width
              task: parent.modelData
              index: parent.index
            }
          }
        }

        Text {
          visible: root.tasks.length === 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(14)
          bottomPadding: Style.space(6)
          text: "No tasks yet — press + to add one"
          color: root.mutedForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.italic: true
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Item {
          width: parent.width
          height: Style.space(30)

          Text {
            id: totalLabel
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰄬  Total: " + root.totalText
            color: root.anyRunning ? root.contentForeground : root.mutedForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            PanelActionButton {
              iconText: "󰜉"
              tooltipText: "Reset every timer to 00:00:00"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              hoverColor: root.bar ? root.bar.urgent : Color.urgent
              bordered: true
              enabled: root.tasks.length > 0
              onClicked: root.resetAllTimers()
            }

            PanelActionButton {
              iconText: "󰐕"
              tooltipText: "Add task"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              bordered: true
              onClicked: root.addTask()
            }
          }
        }
      }
    }
  }

  // A single task row: status dot, title, elapsed time, and a chevron that
  // reveals the per-task actions. Swaps to an inline title/time editor while
  // this task is the one being edited.
  component TaskRow: CursorSurface {
    id: row
    required property var task
    required property int index

    readonly property bool isEditing: root.editingId === task.id
    readonly property bool isExpanded: root.expandedId === task.id && !isEditing
    readonly property bool isRunning: task.running === true
    readonly property int seconds: TaskModel.elapsedSeconds(task, root.nowMs)
    // Running tasks read at full strength; idle ones recede into the muted
    // tint so the active timers are obvious at a glance.
    readonly property color rowForeground: isRunning ? root.contentForeground : root.mutedForeground

    hasCursor: root.cursorActive && root.cursorIndex === index && !isEditing
    foreground: root.contentForeground
    implicitHeight: rowColumn.implicitHeight + Style.space(6)

    function commit() {
      root.commitEdit(row.task.id, titleField.text, timeField.text)
    }

    Column {
      id: rowColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      // ------------------------------------------------------- display mode
      Item {
        id: bodyItem
        visible: !row.isEditing
        width: parent.width
        height: Style.space(26)

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onContainsMouseChanged: if (containsMouse) {
            root.cursorActive = true
            root.cursorIndex = row.index
          }
        }

        Text {
          id: statusDot
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: row.isRunning ? "◉" : "○"
          color: row.rowForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
        }

        PanelActionButton {
          id: chevron
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          size: Style.space(22)
          iconText: row.isExpanded ? "󰅀" : "󰅂"
          tooltipText: row.isExpanded ? "Hide actions" : "Show actions"
          foreground: row.rowForeground
          fontFamily: root.contentFontFamily
          onClicked: root.toggleExpanded(row.task.id)
        }

        Text {
          id: timeLabel
          anchors.right: chevron.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: TaskModel.formatDuration(row.seconds)
          color: row.rowForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          id: titleLabel
          anchors.left: statusDot.right
          anchors.leftMargin: Style.space(10)
          anchors.right: timeLabel.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: row.task.title
          color: row.rowForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        // Clicking the task name is the fast path for start/stop. Declared
        // after the row-wide hover area so it wins the press.
        MouseArea {
          anchors.top: titleLabel.top
          anchors.bottom: titleLabel.bottom
          anchors.left: statusDot.left
          anchors.right: titleLabel.right
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: if (containsMouse) {
            root.cursorActive = true
            root.cursorIndex = row.index
          }
          onClicked: root.toggleTimer(row.task.id)
        }
      }

      // ---------------------------------------------------------- edit mode
      Column {
        id: editItem
        visible: row.isEditing
        width: parent.width
        spacing: Style.space(6)

        // Seed the fields from the task each time the editor opens, then hand
        // it focus once the items have been laid out.
        onVisibleChanged: if (visible) {
          titleField.text = row.task.title
          timeField.text = TaskModel.formatDuration(row.seconds)
          Qt.callLater(function() {
            titleField.forceActiveFocus()
            titleField.selectAll()
          })
        }

        Item {
          width: parent.width
          height: Math.max(titleField.implicitHeight, timeField.implicitHeight)

          TextField {
            id: timeField
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(86)
            horizontalAlignment: Text.AlignHCenter
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                row.commit()
                event.accepted = true
              } else if (event.key === Qt.Key_Escape) {
                root.cancelEdit()
                event.accepted = true
              }
            }
          }

          TextField {
            id: titleField
            anchors.left: parent.left
            anchors.right: timeField.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: "Task name"
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                row.commit()
                event.accepted = true
              } else if (event.key === Qt.Key_Escape) {
                root.cancelEdit()
                event.accepted = true
              } else if (event.key === Qt.Key_Tab) {
                timeField.forceActiveFocus()
                timeField.selectAll()
                event.accepted = true
              }
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(24)

          PanelActionButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅖"
            tooltipText: "Cancel"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            bordered: true
            onClicked: root.cancelEdit()
          }
        }
      }

      // ------------------------------------------------------- row actions
      Item {
        visible: row.isExpanded
        width: parent.width
        height: Style.space(26)

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          PanelActionButton {
            iconText: row.isRunning ? "󰏤" : "󰐊"
            tooltipText: row.isRunning ? "Pause timer" : "Start timer"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            bordered: true
            onClicked: root.toggleTimer(row.task.id)
          }

          PanelActionButton {
            iconText: "󰜉"
            tooltipText: "Reset timer to 00:00:00"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            bordered: true
            onClicked: root.resetTimer(row.task.id)
          }

          PanelActionButton {
            iconText: "󰏫"
            tooltipText: "Edit title and time"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            bordered: true
            onClicked: root.startEdit(row.task.id)
          }

          PanelActionButton {
            iconText: "󰩹"
            tooltipText: "Delete task"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            hoverColor: root.bar ? root.bar.urgent : Color.urgent
            bordered: true
            onClicked: root.removeTask(row.task.id)
          }
        }
      }
    }
  }
}
