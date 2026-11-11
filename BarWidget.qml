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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args) {
    if (actionProc.running) return
    root.message = ""
    actionProc.command = ["proxyctl"].concat(args)
    actionProc.running = true
  }

  Process {
    id: statusProc
    command: ["proxyctl", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = Model.parseStatus(text)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(code) {
      root.message = Model.errorMessage(actionErr.text, actionOut.text)
      root.refresh()
    }
  }

  Timer {
    interval: 5000
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
    onPressed: function(b) { root.toggle() }
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
          leftText: "Normal"; leftIcon: "󰖟"; leftActive: !root.status.tunnel
          rightText: "Proxy"; rightIcon: "󰒍"; rightActive: root.status.tunnel
          onLeftClicked: root.run(["system", "normal"])
          onRightClicked: root.run(["system", "proxy"])
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
          leftText: "Direct"; leftIcon: "󰖟"; leftActive: root.status.exit === "direct"
          rightText: "Proxy"; rightIcon: "󰒍"; rightActive: root.status.exit === "proxy"
          onLeftClicked: root.run(["tor", "exit", "direct"])
          onRightClicked: root.run(["tor", "exit", "proxy"])
        }

        Row {
          id: torRow
          width: parent.width
          spacing: Style.space(8)
          readonly property real half: (width - spacing) / 2

          Button {
            width: torRow.half
            text: "New IP"
            iconText: "󰑐"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            onClicked: root.run(["tor", "newip"])
          }

          TextField {
            id: rotateField
            width: torRow.half
            placeholderText: root.status.rotate > 0 ? root.status.rotate + " s" : "rotate: s"
            inputMethodHints: Qt.ImhDigitsOnly
            Keys.onEscapePressed: focus = false
            onAccepted: {
              root.run(Model.rotateArgs(text))
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
          placeholderText: root.status.addr !== "" ? root.status.addr : "host:port"
          Keys.onEscapePressed: focus = false
          onAccepted: {
            root.run(Model.addrArgs(text))
            text = ""
            focus = false
          }
        }

        PlainLine {
          text: root.message !== "" ? root.message
              : (root.status.addr === "" ? "No address set"
              : (root.status.reachable ? "Proxy answers" : "Proxy does not answer"))
          opacity: root.message !== "" ? 1 : 0.65
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
    property string rightText
    property string rightIcon
    property bool rightActive
    signal leftClicked()
    signal rightClicked()

    width: parent.width
    spacing: Style.space(8)
    readonly property real half: (width - spacing) / 2

    Button {
      width: choice.half
      text: choice.leftText
      iconText: choice.leftIcon
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
      fontSize: Style.font.bodySmall
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
      bordered: true
      active: choice.rightActive
      onClicked: choice.rightClicked()
    }
  }
}
