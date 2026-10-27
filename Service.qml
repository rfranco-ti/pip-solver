import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "PiPModel.js" as PiPModel

Item {
  id: root

  property var tracked: ({})
  property var pendingCommands: []
  property var history: []
  property string lastAction: ""

  function noteCommand(label, exitCode) {
    var entry = { command: label, exitCode: exitCode }
    var next = root.history.slice(-7)
    next.push(entry)
    root.history = next
    root.lastAction = label + " -> exit " + exitCode
  }

  function track(address) {
    var next = Object.assign({}, root.tracked)
    next[address] = true
    root.tracked = next
  }

  function forget(address) {
    if (!(address in root.tracked)) return
    var next = {}
    for (var existing in root.tracked) {
      if (existing !== address) next[existing] = true
    }
    root.tracked = next
  }

  function runHyprctl(args) {
    root.pendingCommands.push(args)
    pumpCommandQueue()
  }

  function pumpCommandQueue() {
    if (commandProcess.running || root.pendingCommands.length === 0) return
    var args = root.pendingCommands.shift()
    commandProcess.currentLabel = args.join(" ")
    commandProcess.command = args
    commandProcess.running = true
  }

  function registerRules() {
    PiPModel.ruleLuaList().forEach(function(rule) {
      root.runHyprctl(["hyprctl", "eval", "hl.window_rule(" + rule + ")"])
    })
  }

  function scanWindows() {
    if (scanProcess.running) return
    scanProcess.running = true
  }

  function applyToClient(client) {
    if (!PiPModel.matchesTitle(client.title)) return
    var address = PiPModel.toAddress(client.address)
    root.track(address)
    root.applyActions(PiPModel.toSelector(address), PiPModel.actionsFor(client))
  }

  function considerWindow(address, title) {
    if (!PiPModel.matchesTitle(title)) return
    var canonical = PiPModel.toAddress(address)
    root.track(canonical)
    root.applyActions(PiPModel.toSelector(canonical), ["float", "pin", "props"])
  }

  function applyActions(selector, actions) {
    actions.forEach(function(action) {
      if (action === "float") {
        root.runHyprctl(dispatchCall("float", { action: "on", window: selector }))
      } else if (action === "pin") {
        root.runHyprctl(dispatchCall("pin", { action: "on", window: selector }))
      } else if (action === "props") {
        root.runHyprctl(dispatchCall("set_prop", { prop: "keep_aspect_ratio", value: "1", window: selector }))
        root.runHyprctl(dispatchCall("set_prop", { prop: "border_size", value: "2", window: selector }))
        root.runHyprctl(dispatchCall("set_prop", { prop: "idle_inhibit", value: "1", window: selector }))
      }
    })
  }

  function dispatchCall(fn, args) {
    return ["hyprctl", "dispatch", "hl.dsp.window." + fn + "(" + PiPModel.luaTable(args) + ")"]
  }

  function statusJson() {
    return JSON.stringify({
      tracked: Object.keys(root.tracked),
      lastAction: root.lastAction,
      history: root.history
    })
  }

  Component.onCompleted: {
    registerRules()
    scanWindows()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = String(event && event.name ? event.name : "")
      if (name === "openwindow") {
        var opened = event.parse(4)
        root.considerWindow(opened[0], opened[3])
      } else if (name === "windowtitlev2") {
        var retitled = event.parse(2)
        root.considerWindow(retitled[0], retitled[1])
      } else if (name === "closewindow") {
        root.forget(PiPModel.toAddress(String(event.data || "")))
      } else if (name === "configreloaded") {
        root.registerRules()
        root.scanWindows()
      }
    }
  }

  Process {
    id: commandProcess

    property string currentLabel: ""

    onExited: function(exitCode) {
      root.noteCommand(currentLabel, exitCode)
      root.pumpCommandQueue()
    }
  }

  Process {
    id: scanProcess

    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var clients
        try {
          clients = JSON.parse(this.text)
        } catch (error) {
          return
        }
        clients.forEach(function(client) {
          root.applyToClient(client)
        })
        root.lastAction = "scan applied to " + clients.filter(function(client) {
          return PiPModel.matchesTitle(client.title)
        }).length + " window(s)"
      }
    }
  }

  IpcHandler {
    target: "pip-solver"

    function status(): string {
      return root.statusJson()
    }
  }
}
