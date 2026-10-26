import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "dj.music"

  // The service is mounted by omarchy-shell for this plugin id. `bar.shell`
  // is the capability-scoped facade a third-party widget receives; serviceFor()
  // is limited to our own plugin, which is exactly what we need here.
  readonly property var service: root.bar && root.bar.shell
    ? root.bar.shell.serviceFor(root.moduleName) : null
  readonly property var player: root.service ? root.service.activePlayer : null
  readonly property bool hasMedia: root.service ? root.service.hasMedia : false
  readonly property bool playing: root.service ? root.service.isPlaying : false

  readonly property bool alwaysShow: root.boolSetting("alwaysShow", false)
  readonly property bool showArtist: root.boolSetting("showArtist", true)
  readonly property int maxLabelWidth: Math.max(40, Number(root.setting("maxWidth", 220)) || 220)

  property bool popupOpen: false
  function close() { popupOpen = false }

  readonly property string labelText: {
    if (!root.service) return ""
    var title = root.service.title
    var artist = root.service.artist
    if (!title) title = artist
    if (!title) title = root.service.identity
    if (!title) return ""
    if (root.showArtist && artist && artist !== title) return title + "  ·  " + artist
    return title
  }

  readonly property string tooltipText: {
    if (!root.service) return ""
    var text = root.labelText
    var identity = root.service.identity
    if (identity && identity !== text) text += "  ·  " + identity
    return text
  }

  visible: root.player !== null && (root.hasMedia || root.alwaysShow)
  implicitWidth: visible ? contentRow.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  function boolSetting(name, fallback) {
    var value = root.setting(name, fallback)
    if (typeof value === "string")
      return value !== "" && value !== "0" && value.toLowerCase() !== "false"
    return Boolean(value)
  }

  function pad2(value) {
    return value < 10 ? "0" + value : String(value)
  }

  function formatTime(seconds) {
    var total = Number(seconds)
    if (!isFinite(total) || total < 0) total = 0
    total = Math.floor(total)
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var secs = total % 60
    if (hours > 0) return hours + ":" + pad2(minutes) + ":" + pad2(secs)
    return minutes + ":" + pad2(secs)
  }

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: Style.space(6)

    // Three tiny equalizer bars: a compact "is it playing" indicator that
    // still reads clearly at bar size.
    Item {
      id: equalizer
      width: Style.space(11)
      height: Style.space(11)
      anchors.verticalCenter: parent.verticalCenter

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: Math.max(1, Style.space(1))

        Repeater {
          model: 3

          Rectangle {
            required property int index
            width: Math.max(2, Style.space(2))
            height: Math.max(3, Style.space(3))
            radius: width / 2
            color: root.bar.foreground
            opacity: root.playing ? 1.0 : 0.5

            SequentialAnimation on height {
              running: root.playing
              loops: Animation.Infinite
              NumberAnimation {
                from: Math.max(3, Style.space(3))
                to: Style.space(10)
                duration: 380 + index * 140
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                from: Style.space(10)
                to: Math.max(3, Style.space(3))
                duration: 380 + index * 140
                easing.type: Easing.InOutSine
              }
            }
          }
        }
      }
    }

    Item {
      id: labelClip
      width: label.needsScroll ? root.maxLabelWidth : Math.min(root.maxLabelWidth, label.implicitWidth)
      height: label.implicitHeight
      clip: true
      visible: !root.bar.vertical && root.labelText !== ""
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: label
        readonly property bool needsScroll: implicitWidth > root.maxLabelWidth

        textFormat: Text.PlainText
        text: root.labelText
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        onNeedsScrollChanged: if (!needsScroll) x = 0

        SequentialAnimation on x {
          running: label.needsScroll && !root.bar.vertical
          loops: Animation.Infinite

          PauseAnimation { duration: 2200 }
          NumberAnimation {
            from: labelClip.width
            to: -label.implicitWidth
            duration: Math.max(6000, label.implicitWidth * 26)
            easing.type: Easing.Linear
          }
          PauseAnimation { duration: 1200 }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.player) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.service) root.service.togglePlayback()
      } else if (mouse.button === Qt.RightButton) {
        if (root.service) root.service.cycleSource(1)
      } else {
        root.popupOpen = !root.popupOpen
      }
    }

    onWheel: function(wheel) {
      if (!root.service) return
      if (wheel.angleDelta.y > 0) root.service.previous()
      else if (wheel.angleDelta.y < 0) root.service.next()
    }

    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(body.implicitHeight, Style.space(640))

    Column {
      id: body
      anchors.fill: parent
      spacing: Style.space(10)
      focus: popup.open
      Keys.onEscapePressed: root.popupOpen = false

      Row {
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          id: artFrame
          width: Style.space(92)
          height: Style.space(92)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          Image {
            id: art
            anchors.fill: parent
            anchors.margins: Style.space(2)
            source: root.service ? root.service.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: source !== "" && status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: !art.visible
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          width: parent.width - artFrame.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.service
              ? (root.service.title || root.service.identity || "Nothing playing")
              : "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.service ? root.service.artist : ""
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            visible: text !== ""
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.service ? root.service.album : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            visible: text !== ""
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.service && root.service.identity ? "via " + root.service.identity : ""
            color: Commons.Color.accent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            visible: text !== ""
          }
        }
      }

      // Seek bar + elapsed/total time. Hidden for live streams, where MPRIS has
      // no meaningful length or seek target.
      Column {
        width: parent.width
        spacing: Style.space(1)
        visible: root.player !== null

        PanelSlider {
          id: progress
          width: parent.width
          bar: root.bar
          minimum: 0
          maximum: root.service && root.service.lengthSupported
            ? Math.max(1, root.service.length) : 1
          value: root.service && root.service.lengthSupported
            ? Math.min(root.service.position, maximum) : 0
          step: 1
          trackHeight: Math.max(3, Math.round(Style.spacing.controlHeight * 0.09))
          fillColor: Commons.Color.accent
          knobColor: Commons.Color.accent
          trackColor: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          enabled: root.service ? root.service.canSeek : false
          opacity: enabled ? 1.0 : 0.55
          visible: root.service ? root.service.lengthSupported : false
          onReleased: function(value) {
            if (root.service) root.service.seekTo(value)
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: "Live stream"
          color: Qt.darker(root.bar.foreground, 1.6)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          visible: !progress.visible
        }

        Item {
          width: parent.width
          height: Math.max(elapsed.implicitHeight, total.implicitHeight)
          visible: progress.visible

          Text {
            id: elapsed
            anchors.left: parent.left
            textFormat: Text.PlainText
            text: root.formatTime(progress.dragging ? progress.liveValue
              : (root.service ? root.service.position : 0))
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: total
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: root.formatTime(root.service ? root.service.length : 0)
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(2)

        Button {
          iconText: "󰒮"
          tooltipText: "Previous track"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.service ? root.service.canGoPrevious : false
          opacity: enabled ? 1.0 : 0.35
          onClicked: if (root.service) root.service.previous()
        }

        Button {
          text: "-10"
          tooltipText: "Back 10 seconds"
          foreground: root.bar.foreground
          fontSize: Style.font.caption
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.service ? root.service.canSeek : false
          opacity: enabled ? 1.0 : 0.35
          onClicked: if (root.service) root.service.seekBy(-10)
        }

        Button {
          iconText: root.playing ? "󰏤" : "󰐊"
          iconSize: Style.font.iconLarge
          tooltipText: root.playing ? "Pause" : "Play"
          foreground: root.bar.foreground
          bordered: true
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.player !== null
          opacity: enabled ? 1.0 : 0.35
          onClicked: if (root.service) root.service.togglePlayback()
        }

        Button {
          text: "+10"
          tooltipText: "Forward 10 seconds"
          foreground: root.bar.foreground
          fontSize: Style.font.caption
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.service ? root.service.canSeek : false
          opacity: enabled ? 1.0 : 0.35
          onClicked: if (root.service) root.service.seekBy(10)
        }

        Button {
          iconText: "󰒭"
          tooltipText: "Next track"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.service ? root.service.canGoNext : false
          opacity: enabled ? 1.0 : 0.35
          onClicked: if (root.service) root.service.next()
        }
      }

      PanelSeparator {
        visible: root.service !== null && root.service.sourceCount > 1
        foreground: root.bar.foreground
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.service !== null && root.service.sourceCount > 1

        PanelSectionHeader {
          text: "Sources"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        ScrollView {
          id: sourceScroll
          width: parent.width
          height: Math.min(sourceColumn.implicitHeight, Style.space(184))
          clip: true
          contentWidth: availableWidth
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          Column {
            id: sourceColumn
            width: sourceScroll.availableWidth
            spacing: Style.space(3)

            Repeater {
              model: root.service ? root.service.sourcePlayers : []

              BorderSurface {
                id: sourceRow
                required property var modelData

                readonly property var sourcePlayer: modelData
                readonly property bool selected: root.service && root.service.currentPlayerKey === root.service.playerKey(sourcePlayer)
                readonly property string sourceTitle: sourcePlayer
                  ? (sourcePlayer.trackTitle || root.service.appLabel(sourcePlayer)) : ""
                readonly property string sourceDetail: sourcePlayer
                  ? (sourcePlayer.trackTitle
                    ? (sourcePlayer.trackArtist || sourcePlayer.trackAlbum || root.service.appLabel(sourcePlayer))
                    : "No track")
                  : ""

                width: sourceColumn.width
                height: Style.space(42)
                radius: Style.cornerRadius
                color: selected
                  ? Style.selectedFillFor(root.bar.foreground, Commons.Color.accent)
                  : (sourceMouse.containsMouse
                    ? Style.hoverFillFor(root.bar.foreground, Commons.Color.accent)
                    : "transparent")
                borderSpec: selected
                  ? Border.controlSpec("selected", root.bar.foreground, Commons.Color.accent)
                  : Border.none()

                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    width: Style.space(16)
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: sourceRow.sourcePlayer && sourceRow.sourcePlayer.isPlaying ? "󰏤" : "󰐊"
                    color: sourceRow.selected ? Commons.Color.accent : root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Column {
                    width: parent.width - Style.space(16) - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: sourceRow.sourceTitle
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: sourceRow.selected
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: sourceRow.sourceDetail
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }
                }

                MouseArea {
                  id: sourceMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.service && sourceRow.sourcePlayer)
                      root.service.selectPlayer(root.service.playerKey(sourceRow.sourcePlayer))
                  }
                  onEntered: if (root.bar)
                    root.bar.showTooltip(sourceRow, sourceRow.sourceTitle
                      + (sourceRow.sourceDetail ? "  ·  " + sourceRow.sourceDetail : ""))
                  onExited: if (root.bar) root.bar.hideTooltip(sourceRow)
                }
              }
            }
          }
        }
      }
    }
  }
}
