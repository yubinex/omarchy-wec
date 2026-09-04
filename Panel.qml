import QtQuick
import qs.Commons
import qs.Ui

// Compact calendar popout. The bar widget owns fetching; this only presents
// the latest parsed calendar so opening it never triggers a network request.
Panel {
  id: root
  moduleName: "yubinex.wec"
  manageIpc: false

  property var anchorItem: null
  property var races: []
  property double nowMs: Date.now()
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.55)

  readonly property var nextRace: {
    for (var i = 0; i < races.length; ++i) {
      if (raceEnd(races[i]) >= nowMs) return races[i]
    }
    return null
  }

  function dateMs(iso) {
    var parts = String(iso).split("-")
    return Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12)
  }

  function raceEnd(race) { return dateMs(race.date) + 12 * 60 * 60 * 1000 }

  function longCountdown(race) {
    var days = Math.ceil(Math.max(0, dateMs(race.date) - nowMs) / 86400000)
    if (days === 0) return "Race day"
    if (days === 1) return "Race in 1 day"
    var weeks = Math.floor(days / 7)
    var remainder = days % 7
    if (weeks === 0) return "Race in " + days + " days"
    return "Race in " + weeks + " week" + (weeks === 1 ? "" : "s")
      + (remainder ? " and " + remainder + " day" + (remainder === 1 ? "" : "s") : "")
  }

  function dateText(race) { return Qt.formatDate(new Date(dateMs(race.date)), "dddd, d MMMM yyyy") }

  function sessionStatus(session) {
    var start = Date.parse(session.start)
    var duration = session.name === "Race" ? 6 * 60 * 60 * 1000 : 90 * 60 * 1000
    if (nowMs >= start + duration) return "DONE"
    if (nowMs >= start) return "LIVE"
    var minutes = Math.ceil((start - nowMs) / 60000)
    if (minutes < 60) return "IN " + minutes + "M"
    var hours = Math.floor(minutes / 60)
    return "IN " + hours + "H " + (minutes % 60) + "M"
  }

  function raceDetails(race) {
    var details = {
      "Lone Star Le Mans": { venue: "Circuit of the Americas", location: "Austin, Texas · United States", duration: "6-hour race", round: "Round 6", sessions: [
        { day: "Fri 4 Sep", name: "Free Practice 1", time: "11:30", start: "2026-09-04T11:30:00-05:00" },
        { day: "Fri 4 Sep", name: "Free Practice 2", time: "16:00", start: "2026-09-04T16:00:00-05:00" },
        { day: "Sat 5 Sep", name: "Free Practice 3", time: "11:00", start: "2026-09-05T11:00:00-05:00" },
        { day: "Sat 5 Sep", name: "Qualifying + Hyperpole", time: "15:00", start: "2026-09-05T15:00:00-05:00" },
        { day: "Sun 6 Sep", name: "Race", time: "13:00", start: "2026-09-06T13:00:00-05:00" }
      ] },
      "6 Hours of Fuji": { venue: "Fuji Speedway", location: "Oyama, Shizuoka · Japan", duration: "6-hour race", round: "Round 7" },
      "6 Hours of Barcelona": { venue: "Circuit de Barcelona-Catalunya", location: "Montmeló · Spain", duration: "6-hour race", round: "Round 8" },
      "6 Hours of Monza": { venue: "Autodromo Nazionale Monza", location: "Monza · Italy", duration: "6-hour race", round: "Round 9" }
    }
    return details[race.name] || { venue: "FIA World Endurance Championship", location: "Venue details on fiawec.com", duration: "Endurance race", round: "Championship round", sessions: [] }
  }

  function followingRaces() {
    if (!nextRace) return races.slice(0, 3)
    for (var i = 0; i < races.length; ++i) {
      if (races[i].name === nextRace.name && races[i].date === nextRace.date)
        return races.slice(i + 1, i + 4)
    }
    return races.slice(0, 3)
  }

  function open() { controller.show() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: Style.space(520)
    contentHeight: Style.space(560)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(24)
      spacing: Style.space(12)

      Text {
        text: "FIA WORLD ENDURANCE CHAMPIONSHIP"
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Text {
        text: root.nextRace ? root.nextRace.name : "No upcoming race"
        color: root.fg
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 24
        font.bold: true
      }

      Text {
        visible: root.nextRace !== null
        text: root.nextRace ? root.dateText(root.nextRace) : ""
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 15
      }

      Text {
        visible: root.nextRace !== null
        text: root.nextRace ? root.longCountdown(root.nextRace) : ""
        color: root.fg
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      PanelSeparator { width: parent.width }

      Row {
        width: parent.width
        spacing: Style.space(36)
        visible: root.nextRace !== null

        Column {
          width: parent.width * 0.62
          spacing: Style.space(4)
          Text { text: "VENUE"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
          Text { text: root.nextRace ? root.raceDetails(root.nextRace).venue : ""; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15 }
          Text { text: root.nextRace ? root.raceDetails(root.nextRace).location : ""; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
        }
        Column {
          spacing: Style.space(4)
          Text { text: "FORMAT"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
          Text { text: root.nextRace ? root.raceDetails(root.nextRace).duration : ""; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15 }
          Text { text: root.nextRace ? root.raceDetails(root.nextRace).round : ""; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
        }
      }

      PanelSeparator { width: parent.width }

      Column {
        width: parent.width
        visible: root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0
        spacing: Style.space(7)
        Text { text: "WEEKEND SCHEDULE · TRACK TIME"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
        Repeater {
          model: root.nextRace ? root.raceDetails(root.nextRace).sessions : []
          delegate: Row {
            required property var modelData
            width: parent.width
            Text { width: Style.space(100); text: modelData.day; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
            Text { width: parent.width - Style.space(230); text: modelData.name; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
            Text { width: Style.space(60); text: modelData.time; horizontalAlignment: Text.AlignRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: modelData.name === "Race" }
            Text { width: Style.space(70); text: root.sessionStatus(modelData); horizontalAlignment: Text.AlignRight; color: root.sessionStatus(modelData) === "LIVE" ? "#e0b84f" : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
          }
        }
      }

      PanelSeparator { width: parent.width; visible: root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0 }

      Text {
        text: "UPCOMING RACES"
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Repeater {
        model: root.followingRaces()
        delegate: Row {
          required property var modelData
          width: parent.width
          spacing: Style.space(12)

          Text {
            width: Style.space(108)
            text: Qt.formatDate(new Date(root.dateMs(modelData.date)), "d MMM yyyy")
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
          Text {
            width: parent.width - Style.space(120)
            text: modelData.name
            color: root.fg
            elide: Text.ElideRight
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
        }
      }
    }
  }
}
