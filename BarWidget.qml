import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Every action runs `proxyctl` with an argument list, never through a shell
// string, so text typed into the panel cannot become a command.
Panel {
  id: root
  moduleName: "sups.proxyctl"
  ipcTarget: "sups.proxyctl"

  property var status: Model.parseStatus("")
  property string message: ""
  property string pendingAction: ""
  property bool pendingRefresh: false
  readonly property bool actionRunning: actionProc.running

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (statusProc.running) {
      root.pendingRefresh = true
    } else {
      statusProc.running = true
    }
  }

  function run(args, actionKey) {
    if (actionProc.running) return
    root.message = ""
    root.pendingAction = actionKey || ""
    actionProc.command = ["proxyctl"].concat(args)
    actionProc.running = true
  }

  Process {
    id: statusProc
    command: ["proxyctl", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.status = Model.parseStatus(text)
        if (root.pendingRefresh) {
          root.pendingRefresh = false
          statusProc.running = true
        }
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(code) {
      root.pendingAction = ""
      root.message = Model.errorMessage(actionErr.text, actionOut.text)
      root.refresh()
    }
  }

  Timer {
    interval: root.opened ? 3000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barIcon(root.status)
    active: root.opened || root.status.tunnel
    tooltipText: Model.tooltip(root.status)
    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        var toNormal = root.status.want === "proxy"
        root.run(["system", toNormal ? "normal" : "proxy"], toNormal ? "sys:normal" : "sys:proxy")
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      implicitHeight: mainCol.implicitHeight
      anchors.fill: parent
      blocked: rotateField.activeFocus || addrField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelSectionHeader { text: "System"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        ChoiceRow {
          leftText: "Normal"; leftIcon: "󰖟"
          leftActive: root.pendingAction === "sys:normal" || (root.pendingAction !== "sys:proxy" && root.status.want !== "proxy")
          leftPending: root.pendingAction === "sys:normal"
          rightText: "Proxy"; rightIcon: "󰒍"
          rightActive: root.pendingAction === "sys:proxy" || (root.pendingAction !== "sys:normal" && root.status.want === "proxy")
          rightPending: root.pendingAction === "sys:proxy"
          onLeftClicked: root.run(["system", "normal"], "sys:normal")
          onRightClicked: root.run(["system", "proxy"], "sys:proxy")
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: root.status.torActive
              ? "Tor exit · " + (root.status.torIp !== "" ? root.status.torIp : "running")
              : "Tor exit · stopped"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }
        ChoiceRow {
          leftText: "Direct"; leftIcon: "󰖟"
          leftActive: root.pendingAction === "tor:direct" || (root.pendingAction !== "tor:proxy" && root.status.exit === "direct")
          leftPending: root.pendingAction === "tor:direct"
          rightText: "Proxy"; rightIcon: "󰒍"
          rightActive: root.pendingAction === "tor:proxy" || (root.pendingAction !== "tor:direct" && root.status.exit === "proxy")
          rightPending: root.pendingAction === "tor:proxy"
          onLeftClicked: root.run(["tor", "exit", "direct"], "tor:direct")
          onRightClicked: root.run(["tor", "exit", "proxy"], "tor:proxy")
        }

        Row {
          id: torRow
          width: parent.width
          spacing: Style.space(8)
          readonly property real half: (width - spacing) / 2

          Button {
            width: torRow.half
            text: root.pendingAction === "tor:newip" ? "Rotating..." : "New IP"
            iconText: "󰑐"
            iconSpinning: root.pendingAction === "tor:newip"
            enabled: !root.actionRunning
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            onClicked: root.run(["tor", "newip"], "tor:newip")
          }

          TextField {
            id: rotateField
            width: torRow.half
            enabled: !root.actionRunning
            placeholderText: root.status.rotate > 0 ? root.status.rotate + " s" : "rotate: s"
            inputMethodHints: Qt.ImhDigitsOnly
            Keys.onEscapePressed: focus = false
            onAccepted: {
              root.run(Model.rotateArgs(text), "tor:rotate")
              text = ""
              focus = false
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader { text: "Proxy address"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        TextField {
          id: addrField
          width: parent.width
          enabled: !root.actionRunning
          placeholderText: root.status.addr !== "" ? root.status.addr : "host:port"
          Keys.onEscapePressed: focus = false
          onAccepted: {
            root.run(Model.addrArgs(text), "sys:addr")
            text = ""
            focus = false
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: Model.nodpiHeader(root.status)
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }
        ChoiceRow {
          leftText: "Off"; leftIcon: "󰦞"
          leftActive: root.pendingAction === "nodpi:off" || (root.pendingAction !== "nodpi:on" && !root.status.nodpiActive)
          leftPending: root.pendingAction === "nodpi:off"
          rightText: "On"; rightIcon: "󰕥"
          rightActive: root.pendingAction === "nodpi:on" || (root.pendingAction !== "nodpi:off" && root.status.nodpiActive)
          rightPending: root.pendingAction === "nodpi:on"
          onLeftClicked: root.run(["nodpi", "off"], "nodpi:off")
          onRightClicked: root.run(["nodpi", "on"], "nodpi:on")
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: root.status.defaultsSaved ? "Boot defaults · saved" : "Boot defaults"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }
        PlainLine {
          text: Model.defaultsSummary(root.status)
          opacity: 0.75
        }
        ChoiceRow {
          leftText: "Save current"; leftIcon: "󰆓"
          leftActive: root.pendingAction === "def:save"
          leftPending: root.pendingAction === "def:save"
          rightText: "Apply"; rightIcon: "󰑓"
          rightActive: root.pendingAction === "def:apply"
          rightPending: root.pendingAction === "def:apply"
          onLeftClicked: root.run(["defaults", "save"], "def:save")
          onRightClicked: root.run(["defaults", "apply"], "def:apply")
        }

        PlainLine {
          text: root.actionRunning && root.pendingAction !== "" ? "Applying changes..."
              : (root.message !== "" ? root.message
              : (root.status.addr === "" ? "No address set"
              : (root.status.want === "proxy" && !root.status.tunnel ? "Waiting for proxy..."
              : (root.status.reachable ? "Proxy answers" : "Proxy does not answer"))))
          opacity: (root.actionRunning || root.message !== "") ? 1 : 0.65
        }
      }
    }
  }

  component PlainLine: Text {
    width: parent.width
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component ChoiceRow: Row {
    id: choice
    property string leftText
    property string leftIcon
    property bool leftActive
    property bool leftPending: false
    property string rightText
    property string rightIcon
    property bool rightActive
    property bool rightPending: false
    signal leftClicked()
    signal rightClicked()

    width: parent.width
    spacing: Style.space(8)
    readonly property real half: (width - spacing) / 2

    Button {
      width: choice.half
      text: choice.leftText
      iconText: choice.leftIcon
      iconSpinning: choice.leftPending
      enabled: !root.actionRunning || choice.leftPending
      fontSize: Style.font.bodySmall
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
      bordered: true
      active: choice.leftActive
      onClicked: choice.leftClicked()
    }

    Button {
      width: choice.half
      text: choice.rightText
      iconText: choice.rightIcon
      iconSpinning: choice.rightPending
      enabled: !root.actionRunning || choice.rightPending
      fontSize: Style.font.bodySmall
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
      bordered: true
      active: choice.rightActive
      onClicked: choice.rightClicked()
    }
  }
}
