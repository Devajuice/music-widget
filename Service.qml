import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Headless MPRIS service for the Music bar widget.
//
// Everything that talks to a player lives here so the bar widget is free to
// focus on presentation. The service is mounted once by omarchy-shell and is
// shared by every monitor's bar instance (and by IPC callers).
Item {
  id: root

  // Injected by omarchy-shell for third-party plugins.
  property var shell: null

  // Player explicitly chosen in the popup. Empty means "pick automatically":
  // first playing player, then the first one with track metadata.
  property string preferredPlayerKey: ""

  // Mpris.players itself only notifies when players appear/disappear. Bump
  // this whenever a player's playback state or metadata changes so the
  // active-player/source bindings below re-evaluate.
  property int revision: 0

  readonly property var players: Mpris.players ? Mpris.players.values : []

  function bump() {
    revision = revision + 1
  }

  function appLabel(player) {
    if (!player) return ""
    return String(player.identity || player.desktopEntry || "Unknown player")
  }

  function playerKey(player) {
    if (!player) return ""
    if (player.dbusName) return String(player.dbusName)
    if (player.uniqueId !== undefined && player.uniqueId !== null) return "unique:" + String(player.uniqueId)
    return appLabel(player)
  }

  function playerForKey(key) {
    if (!key) return null
    for (var i = 0; i < players.length; i++) {
      if (playerKey(players[i]) === key) return players[i]
    }
    return null
  }

  function hasTrackMetadata(player) {
    if (!player) return false
    return Boolean(player.trackTitle || player.trackArtist || player.trackAlbum || player.trackArtUrl)
  }

  function isUsable(player) {
    if (!player) return false
    return hasTrackMetadata(player) || Boolean(player.canControl)
  }

  readonly property var activePlayer: {
    var tick = revision

    if (preferredPlayerKey !== "") {
      var pinned = playerForKey(preferredPlayerKey)
      if (pinned && isUsable(pinned)) return pinned
    }

    var playing = null
    var withTrack = null
    var controllable = null
    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      if (!isUsable(player)) continue
      if (player.isPlaying && !playing) playing = player
      else if (hasTrackMetadata(player) && !withTrack) withTrack = player
      else if (!controllable) controllable = player
    }
    return playing || withTrack || controllable || null
  }

  readonly property var sourcePlayers: {
    var tick = revision
    var list = []
    for (var i = 0; i < players.length; i++) {
      if (isUsable(players[i])) list.push(players[i])
    }
    list.sort(function(a, b) {
      if (Boolean(a.isPlaying) !== Boolean(b.isPlaying)) return a.isPlaying ? -1 : 1
      return appLabel(a).localeCompare(appLabel(b))
    })
    return list
  }

  readonly property int sourceCount: sourcePlayers.length

  function normalizeArtUrl(url) {
    var value = String(url || "")
    if (value === "") return ""
    if (/^(file|https?|data|image|qrc):/i.test(value)) return value
    if (value.charAt(0) === "/") return "file://" + value
    return value
  }

  readonly property string title: activePlayer ? String(activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer ? String(activePlayer.trackAlbum || "") : ""
  readonly property string artUrl: activePlayer ? normalizeArtUrl(activePlayer.trackArtUrl) : ""
  readonly property string identity: activePlayer ? appLabel(activePlayer) : ""
  readonly property string currentPlayerKey: activePlayer ? playerKey(activePlayer) : ""

  readonly property bool hasMedia: Boolean(title || artist)
  readonly property bool hasPlayer: activePlayer !== null
  readonly property bool isPlaying: activePlayer ? Boolean(activePlayer.isPlaying) : false
  readonly property bool canGoNext: activePlayer ? Boolean(activePlayer.canGoNext) : false
  readonly property bool canGoPrevious: activePlayer ? Boolean(activePlayer.canGoPrevious) : false
  readonly property bool canSeek: activePlayer ? Boolean(activePlayer.canSeek) : false
  readonly property bool lengthSupported: activePlayer ? Boolean(activePlayer.lengthSupported) : false

  // `position` only updates reactively when someone emits positionChanged().
  // The ticker below does that while something is playing, as recommended by
  // Quickshell's MprisPlayer documentation.
  readonly property real position: activePlayer ? activePlayer.position : 0
  readonly property real length: activePlayer ? activePlayer.length : 0

  Timer {
    interval: 500
    repeat: true
    running: root.isPlaying && root.activePlayer !== null && root.activePlayer.positionSupported
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }

  // Re-run selection and source ordering when any individual player changes.
  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData

      function onIsPlayingChanged() { root.bump() }
      function onPlaybackStateChanged() { root.bump() }
      function onMetadataChanged() { root.bump() }
      function onTrackChanged() { root.bump() }
      function onPostTrackChanged() { root.bump() }
    }
  }

  function selectPlayer(key) {
    var player = playerForKey(String(key || ""))
    if (!player || !isUsable(player)) return false
    preferredPlayerKey = playerKey(player)
    return true
  }

  function cycleSource(delta) {
    if (sourcePlayers.length === 0) return false
    var index = 0
    for (var i = 0; i < sourcePlayers.length; i++) {
      if (playerKey(sourcePlayers[i]) === currentPlayerKey) {
        index = i
        break
      }
    }
    index = (index + delta + sourcePlayers.length) % sourcePlayers.length
    return selectPlayer(playerKey(sourcePlayers[index]))
  }

  function togglePlayback() {
    var player = activePlayer
    if (!player) return false
    if (player.canTogglePlaying) {
      player.togglePlaying()
      return true
    }
    if (player.isPlaying && player.canPause) {
      player.pause()
      return true
    }
    if (!player.isPlaying && player.canPlay) {
      player.play()
      return true
    }
    return false
  }

  function play() {
    var player = activePlayer
    if (!player || !player.canPlay) return false
    player.play()
    return true
  }

  function pause() {
    var player = activePlayer
    if (!player || !player.canPause) return false
    player.pause()
    return true
  }

  function next() {
    var player = activePlayer
    if (!player || !player.canGoNext) return false
    player.next()
    return true
  }

  function previous() {
    var player = activePlayer
    if (!player || !player.canGoPrevious) return false
    player.previous()
    return true
  }

  function seekBy(seconds) {
    var player = activePlayer
    var offset = Number(seconds)
    if (!player || !isFinite(offset) || !player.canSeek) return false
    player.seek(offset)
    player.positionChanged()
    return true
  }

  function seekTo(seconds) {
    var player = activePlayer
    var target = Number(seconds)
    if (!player || !isFinite(target) || !player.canSeek || !player.positionSupported) return false
    player.position = Math.max(0, target)
    player.positionChanged()
    return true
  }

  function statusJson() {
    var player = activePlayer
    return JSON.stringify({
      playerCount: sourceCount,
      hasMedia: hasMedia,
      playing: isPlaying,
      identity: identity,
      title: title,
      artist: artist,
      album: album,
      artUrl: artUrl,
      canGoNext: canGoNext,
      canGoPrevious: canGoPrevious,
      canTogglePlaying: player ? Boolean(player.canTogglePlaying) : false,
      canSeek: canSeek,
      position: position,
      length: length
    })
  }

  IpcHandler {
    target: "music"

    function status(): string {
      return root.statusJson()
    }

    function playPause(): string {
      return root.togglePlayback() ? "ok" : "unhandled"
    }

    function play(): string {
      return root.play() ? "ok" : "unhandled"
    }

    function pause(): string {
      return root.pause() ? "ok" : "unhandled"
    }

    function next(): string {
      return root.next() ? "ok" : "unhandled"
    }

    function previous(): string {
      return root.previous() ? "ok" : "unhandled"
    }

    function seekBack(): string {
      return root.seekBy(-10) ? "ok" : "unhandled"
    }

    function seekForward(): string {
      return root.seekBy(10) ? "ok" : "unhandled"
    }

    function seekTo(seconds: string): string {
      return root.seekTo(Number(seconds)) ? "ok" : "unhandled"
    }

    function sourceNext(): string {
      return root.cycleSource(1) ? "ok" : "unhandled"
    }

    function sourcePrevious(): string {
      return root.cycleSource(-1) ? "ok" : "unhandled"
    }

    function selectSource(key: string): string {
      return root.selectPlayer(String(key)) ? "ok" : "unknown"
    }

    function ping(): string {
      return "ok"
    }
  }
}
