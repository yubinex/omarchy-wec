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
  property var hostWidget: null
  property var races: []
  property double nowMs: Date.now()
  property double calendarUpdatedMs: 0
  property double standingsUpdatedMs: 0
  property var weekendDetails: ({})
  property string activeTab: "weekend"
  property string standingsTab: "manufacturers"
  property bool showAllStandings: false
  property var expandedScheduleDays: ({})
  readonly property bool showRaceFlags: setting("showRaceFlags", true)
  readonly property bool showCompletedSessions: setting("showCompletedSessions", true)
  // Official FIA WEC classifications, captured on 4 Sep 2026. These remain
  // explicitly labelled as a snapshot until each classification is fetched.
  property var standings: ({
    manufacturers: [
    { position: 1, name: "Toyota", points: 132 },
    { position: 2, name: "BMW", points: 127 },
    { position: 3, name: "Ferrari", points: 88 },
    { position: 4, name: "Cadillac", points: 60 },
    { position: 5, name: "Alpine", points: 41 },
    { position: 6, name: "Aston Martin", points: 40 },
    { position: 7, name: "Peugeot", points: 15 },
    { position: 8, name: "Genesis", points: 6 }
    ],
    hypercarDrivers: [
      { position: 1, name: "René Rast / Robin Frijns", detail: "#20 BMW", points: 75 },
      { position: 2, name: "Kobayashi / Conway / de Vries", detail: "#7 Toyota", points: 75 },
      { position: 3, name: "Sheldon van der Linde", detail: "#20 BMW", points: 65 },
      { position: 4, name: "Pier Guidi / Giovinazzi / Calado", detail: "#51 Ferrari", points: 57 },
      { position: 5, name: "Hartley / Hirakawa / Buemi", detail: "#8 Toyota", points: 56 },
      { position: 6, name: "Magnussen / Marciello", detail: "#15 BMW", points: 50 }
    ],
    lmgt3Teams: [
      { position: 1, name: "TF Sport", detail: "#33 Corvette", points: 76 },
      { position: 2, name: "The Bend Manthey", detail: "#92 Porsche", points: 49 },
      { position: 3, name: "Team WRT", detail: "#69 BMW", points: 43 },
      { position: 4, name: "Racing Team Turkey by TF", detail: "#34 Corvette", points: 43 },
      { position: 5, name: "Vista AF Corse", detail: "#21 Ferrari", points: 42 },
      { position: 6, name: "Akkodis ASP Team", detail: "#87 Lexus", points: 38 }
    ],
    lmgt3Drivers: [
      { position: 1, name: "Jonny Edgar", detail: "#33 Corvette", points: 76 },
      { position: 2, name: "Nicky Catsburg", detail: "#33 Corvette", points: 72 },
      { position: 3, name: "Ben Keating", detail: "#33 Corvette", points: 54 },
      { position: 4, name: "Pera / Lietz / Shahin", detail: "#92 Porsche", points: 49 },
      { position: 5, name: "McIntosh / Harper / Thompson", detail: "#69 BMW", points: 43 },
      { position: 6, name: "Eastwood / Dempsey / Yoluç", detail: "#34 Corvette", points: 43 }
    ]
  })
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.55)
  readonly property bool compactLayout: popup.contentWidth < Style.space(400)
  // KeyboardPanel can fit to very narrow work areas. At this size, preserve
  // primary information rather than letting fixed metadata overlap it.
  readonly property bool veryCompactLayout: popup.contentWidth < Style.space(240)

  readonly property var nextRace: {
    for (var i = 0; i < races.length; ++i) {
      if (raceEnd(races[i]) >= nowMs) return races[i]
    }
    return null
  }
  readonly property var featuredSession: {
    if (!nextRace) return null
    var sessions = raceDetails(nextRace).sessions || []
    for (var i = 0; i < sessions.length; ++i)
      if (sessions[i].officialStatus !== "EventCompleted") return sessions[i]
    return null
  }
  readonly property var raceSession: {
    if (!nextRace) return null
    var sessions = raceDetails(nextRace).sessions || []
    for (var i = 0; i < sessions.length; ++i)
      if (sessions[i].name === "Race") return sessions[i]
    return null
  }

  function dateMs(iso) {
    var parts = String(iso).split("-")
    return Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12)
  }

  function raceEnd(race) {
    var details = race.slug ? weekendDetails[race.slug] : null
    var sessions = details ? details.sessions : []
    if (sessions.length) {
      var finalSession = sessions[sessions.length - 1]
      if (finalSession.officialStatus !== "EventCompleted") return Infinity
      return Date.parse(finalSession.start)
    }
    return dateMs(race.date) + 12 * 60 * 60 * 1000
  }

  function calendarDaysUntil(race) {
    var today = new Date(nowMs)
    var todayMs = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
    var raceMs = Date.UTC(Number(race.date.slice(0, 4)), Number(race.date.slice(5, 7)) - 1, Number(race.date.slice(8, 10)))
    return Math.max(0, Math.round((raceMs - todayMs) / 86400000))
  }

  function raceStartMs(race) {
    var sessions = raceDetails(race).sessions || []
    for (var i = 0; i < sessions.length; ++i) {
      if (sessions[i].name === "Race") return Date.parse(sessions[i].start)
    }
    return 0
  }

  function longCountdown(race) {
    var start = raceStartMs(race)
    if (start) {
      var remaining = start - nowMs
      if (remaining <= 0) return "Race live"
      if (remaining < 86400000) {
        var minutes = Math.ceil(remaining / 60000)
        return "Race in " + twoDigits(Math.floor(minutes / 60)) + "H " + twoDigits(minutes % 60) + "M"
      }
    }
    var days = calendarDaysUntil(race)
    if (days === 0) return "Race day"
    if (days === 1) return "Race in 1 day"
    var weeks = Math.floor(days / 7)
    var remainder = days % 7
    if (weeks === 0) return "Race in " + days + " days"
    return "Race in " + weeks + " week" + (weeks === 1 ? "" : "s")
      + (remainder ? " and " + remainder + " day" + (remainder === 1 ? "" : "s") : "")
  }

  function dateText(race) {
    var start = raceStartMs(race)
    return Qt.formatDate(new Date(start || dateMs(race.date)), "dddd, d MMMM yyyy")
  }

  function localTimeZone() { return Qt.formatDateTime(new Date(), "t") }

  function raceFlag(race) {
    var flags = {
      US: "🇺🇸", JP: "🇯🇵", ES: "🇪🇸", IT: "🇮🇹", QA: "🇶🇦", GB: "🇬🇧",
      BE: "🇧🇪", FR: "🇫🇷", BR: "🇧🇷", BH: "🇧🇭"
    }
    return flags[race.countryCode || raceDetails(race).countryCode] || ""
  }

  function calendarSourceText() {
    if (calendarUpdatedMs <= 0) return "Official FIA WEC calendar · bundled schedule"
    return "Official FIA WEC calendar · updated "
      + Qt.formatDateTime(new Date(calendarUpdatedMs), "d MMM, HH:mm")
  }

  function standingsTitle() {
    var titles = {
      manufacturers: "HYPERCAR MANUFACTURERS",
      hypercarDrivers: "HYPERCAR DRIVERS",
      lmgt3Teams: "LMGT3 TEAMS",
      lmgt3Drivers: "LMGT3 DRIVERS"
    }
    return titles[standingsTab]
  }

  function standingsSourceText() {
    if (standingsUpdatedMs <= 0) return "Official FIA WEC standings · snapshot: 4 Sep 2026"
    return "Official FIA WEC standings · updated "
      + Qt.formatDateTime(new Date(standingsUpdatedMs), "d MMM, HH:mm")
  }

  function visibleStandings() {
    var rows = standings[standingsTab] || []
    return showAllStandings ? rows : rows.slice(0, 10)
  }

  function pointsGap(entry) {
    var rows = standings[standingsTab] || []
    if (entry.position === 1 || !rows.length) return ""
    return "−" + (rows[0].points - entry.points) + " pts"
  }

  function persistSettings(values) {
    var entry = { id: moduleName }
    for (var existing in settings) if (existing !== "id") entry[existing] = settings[existing]
    for (var key in values) entry[key] = values[key]
    settings = entry
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }

  function visibleSessions(race) {
    var sessions = raceDetails(race).sessions || []
    if (showCompletedSessions) return sessions
    return sessions.filter(function(session) { return session.officialStatus !== "EventCompleted" })
  }

  function visibleScheduleDays(race) {
    var sessions = visibleSessions(race)
    var days = []
    for (var i = 0; i < sessions.length; ++i) {
      var session = sessions[i]
      var key = Qt.formatDate(new Date(session.start), "yyyy-MM-dd")
      if (!days.length || days[days.length - 1].key !== key)
        days.push({ key: key, label: Qt.formatDate(new Date(session.start), "dddd · d MMMM"), sessions: [] })
      days[days.length - 1].sessions.push(session)
    }
    return days
  }

  function isScheduleDayExpanded(day) {
    if (expandedScheduleDays[day] !== undefined) return expandedScheduleDays[day]
    return featuredSession && Qt.formatDate(new Date(featuredSession.start), "yyyy-MM-dd") === day
  }

  function toggleScheduleDay(day) {
    var next = Object.assign({}, expandedScheduleDays)
    next[day] = !isScheduleDayExpanded(day)
    expandedScheduleDays = next
  }

  function sessionStatus(session) {
    var start = Date.parse(session.start)
    if (session.officialStatus === "EventCompleted") return "DONE"
    if (nowMs >= start) return "LIVE"
    var minutes = Math.ceil((start - nowMs) / 60000)
    // Match the concise timetable language: only show a short relative
    // marker during the active weekend, never a multi-day wall of numbers.
    if (minutes > 48 * 60) return ""
    if (minutes >= 60) return Math.ceil(minutes / 60) + "h"
    return Math.max(0, minutes) + "m"
  }

  function twoDigits(value) { return value < 10 ? "0" + value : String(value) }

  function sessionStatusColor(session) {
    var minutes = Math.ceil((Date.parse(session.start) - nowMs) / 60000)
    if (sessionStatus(session) === "LIVE") return "#df5b5b"
    if (minutes >= 0 && minutes <= 120) return "#e0b84f"
    return root.dim
  }

  function raceDetails(race) {
    return race && race.slug && weekendDetails[race.slug]
      ? weekendDetails[race.slug]
      : { venue: "Loading official event details…", location: "", trackLength: "", turns: 0, round: "", sessions: [] }
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
    // Anchor the popup to the WEC widget rather than the middle of the bar.
    centerOnBar: false
    // Let KeyboardPanel constrain the card to the active display rather than
    // merely clamping a fixed-width card's position on narrow outputs.
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)
    focusTarget: keyboardCatcher

    PanelKeyCatcher {
      id: keyboardCatcher
      anchors.fill: parent
      z: -1
      onCloseRequested: root.close()
    }

    Flickable {
      id: scroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
      id: content
       width: scroll.width
      spacing: Style.space(12)

       Text {
         visible: root.activeTab === "settings"
         text: "WEC PLUGIN"
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

        Column {
          id: weekendOverview
          width: parent.width
          visible: root.activeTab !== "settings" && root.nextRace !== null
          Column {
            width: parent.width
            spacing: Style.space(8)
            Row {
              width: parent.width
              spacing: Style.space(10)
              Text { id: heroFlag; visible: root.showRaceFlags && !root.veryCompactLayout; width: visible ? implicitWidth : 0; text: root.nextRace ? root.raceFlag(root.nextRace) : ""; font.pixelSize: Style.font.display }
              Column {
                width: Math.max(0, parent.width - heroFlag.width - heroRound.width
                  - (heroFlag.visible ? Style.space(10) : 0)
                  - (heroRound.visible ? Style.space(10) : 0))
                spacing: Style.space(1)
                Text { width: parent.width; text: root.nextRace ? root.nextRace.name.toUpperCase() : "FIA WORLD ENDURANCE CHAMPIONSHIP"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; font.letterSpacing: 1.0 }
                Text { width: parent.width; text: root.nextRace ? root.raceDetails(root.nextRace).venue + " · " + root.raceDetails(root.nextRace).location : ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
              }
              Text { id: heroRound; visible: root.nextRace && root.raceDetails(root.nextRace).round.length > 0 && !root.veryCompactLayout; width: visible ? Math.min(implicitWidth, root.compactLayout ? Style.space(48) : Style.space(72)) : 0; text: root.nextRace ? root.raceDetails(root.nextRace).round.toUpperCase() : ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
            }
            Rectangle { width: parent.width; height: 1; color: root.dim; opacity: 0.35 }
            Row {
              width: parent.width
              spacing: Style.space(12)
              Column {
                id: nextTrack
                width: parent.width * 0.48
                spacing: Style.space(2)
                Text { text: "NEXT ON TRACK"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Text { width: parent.width; text: root.featuredSession ? root.featuredSession.name : "Schedule unavailable"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                Text { width: parent.width; text: root.featuredSession ? Qt.formatDateTime(new Date(root.featuredSession.start), "ddd d MMM · HH:mm") : ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
              Column {
                width: parent.width - nextTrack.width - Style.space(12)
                spacing: Style.space(2)
                Text { text: "RACE START"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Text { width: parent.width; text: root.raceSession ? Qt.formatDateTime(new Date(root.raceSession.start), "ddd d MMM · HH:mm") : root.dateText(root.nextRace); elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                Text { width: parent.width; text: root.longCountdown(root.nextRace).toUpperCase(); elide: Text.ElideRight; color: root.featuredSession && root.sessionStatus(root.featuredSession) === "LIVE" ? "#e10600" : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              }
            }
          }
       }

       Flow {
         width: parent.width
        spacing: Style.space(8)

        Repeater {
          model: [
            { id: "weekend", label: "RACE WEEKEND", compactLabel: "WEEKEND" },
            { id: "standings", label: "STANDINGS", compactLabel: "STANDINGS" }
          ]

          delegate: Rectangle {
            required property var modelData
            implicitWidth: tabLabel.implicitWidth + Style.space(18)
            implicitHeight: Style.space(28)
            radius: Style.space(3)
            color: root.activeTab === modelData.id ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
            border.width: 1
            border.color: root.activeTab === modelData.id ? root.fg : root.dim

            Text {
              id: tabLabel
              anchors.centerIn: parent
              text: root.veryCompactLayout ? modelData.compactLabel : modelData.label
              color: root.activeTab === modelData.id ? root.fg : root.dim
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: 12
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.activeTab = modelData.id
            }
          }
        }

        PanelActionButton {
          iconText: "󰒓"
          tooltipText: "Settings"
          foreground: root.dim
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          size: Style.space(28)
          bordered: true
          onClicked: root.activeTab = "settings"
        }
      }

      Column {
        width: parent.width
        visible: root.activeTab === "weekend" && root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0
        spacing: Style.space(7)
        Text { text: "WEEKEND SCHEDULE"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
        Text { text: "All times in " + root.localTimeZone(); color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
        Repeater {
          model: root.nextRace ? root.visibleScheduleDays(root.nextRace) : []
          delegate: Column {
            id: dayGroup
            required property var modelData
            readonly property bool expanded: root.isScheduleDayExpanded(modelData.key)
            width: parent.width
            spacing: Style.space(4)
            Item {
              width: parent.width
              height: Style.space(18)
              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - dayToggle.implicitWidth)
                text: modelData.label.toUpperCase() + " · " + modelData.sessions.length + " SESSION" + (modelData.sessions.length === 1 ? "" : "S")
                elide: Text.ElideRight
                color: root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 11
                font.bold: true
              }
              Text {
                id: dayToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: dayGroup.expanded ? "⌃" : "⌄"
                color: root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 14
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleScheduleDay(dayGroup.modelData.key)
              }
            }

            Item {
              width: parent.width
              visible: dayGroup.expanded
              height: visible ? sessionsColumn.implicitHeight : 0
              Column {
                id: sessionsColumn
                width: parent.width
                spacing: Style.space(3)
                Repeater {
                  model: dayGroup.modelData.sessions
                   delegate: Item {
                    required property var modelData
                    width: parent.width
                     height: root.compactLayout ? Style.space(40) : Style.space(24)
                    opacity: root.sessionStatus(modelData) === "DONE" ? 0.45 : 1.0
                    readonly property string status: root.sessionStatus(modelData)
                    readonly property bool isRace: modelData.name === "Race"
                     Text { id: sessionTime; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: root.compactLayout ? Style.space(48) : Style.space(64); horizontalAlignment: Text.AlignRight; text: Qt.formatTime(new Date(modelData.start), "HH:mm"); color: isRace || status === "LIVE" ? root.fg : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: isRace || status === "LIVE" }
                     Rectangle { id: sessionMarker; anchors.left: sessionTime.right; anchors.leftMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; width: Style.space(5); height: width; radius: width / 2; color: status === "LIVE" ? "#e10600" : (isRace ? root.fg : root.dim); opacity: isRace || status === "LIVE" ? 1 : 0.45 }
                     Text { id: sessionStatus; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: root.compactLayout ? 0 : Math.min(Math.max(Style.space(54), implicitWidth), Style.space(72)); horizontalAlignment: Text.AlignRight; text: parent.status === "DONE" ? "" : parent.status; elide: Text.ElideRight; color: parent.status === "LIVE" ? "#e10600" : root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: parent.status === "LIVE" }
                     Text { anchors.left: sessionMarker.right; anchors.right: root.compactLayout ? parent.right : sessionStatus.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(12); verticalAlignment: Text.AlignVCenter; text: modelData.name + (root.compactLayout && status && status !== "DONE" ? " · " + status : ""); elide: root.compactLayout ? Text.ElideNone : Text.ElideRight; wrapMode: root.compactLayout ? Text.WordWrap : Text.NoWrap; maximumLineCount: root.compactLayout ? 2 : 1; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: isRace }
                  }
                }
              }
            }
          }
        }
      }

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" && root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0 }

      Text {
        visible: root.activeTab === "weekend"
        text: "UPCOMING RACES"
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Repeater {
        model: root.activeTab === "weekend" ? root.followingRaces() : []
        delegate: Row {
          required property var modelData
          width: parent.width
          spacing: Style.space(12)

          Text {
            width: root.veryCompactLayout ? 0 : Style.space(108)
            text: Qt.formatDate(new Date(root.dateMs(modelData.date)), "d MMM yyyy")
            visible: !root.veryCompactLayout
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
          Text {
            width: root.showRaceFlags && !root.veryCompactLayout ? Style.space(28) : 0
            text: root.raceFlag(modelData)
            visible: root.showRaceFlags && !root.veryCompactLayout
            font.pixelSize: 16
          }
          Text {
             width: Math.max(0, parent.width - (root.veryCompactLayout ? 0 : Style.space(108)) - (root.showRaceFlags && !root.veryCompactLayout ? Style.space(28) : 0) - (root.veryCompactLayout ? 0 : (root.showRaceFlags ? Style.space(24) : Style.space(12))))
            text: modelData.name
            color: root.fg
            elide: Text.ElideRight
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
        }
      }

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Row {
        width: parent.width
        visible: root.activeTab === "weekend" && !root.compactLayout
        Text {
          width: Math.max(0, parent.width - calendarLink.implicitWidth - Style.space(12))
          text: root.calendarSourceText()
          elide: Text.ElideRight
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 12
        }
        Text {
          id: calendarLink
          text: "OPEN FIA WEC ↗"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 12
          font.bold: true
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.bar) root.bar.run("xdg-open https://www.fiawec.com/en/")
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.activeTab === "weekend" && root.compactLayout
        Text { width: parent.width; text: root.calendarSourceText(); elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
        Text {
          text: "OPEN FIA WEC ↗"
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 12
          font.bold: true
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.bar) root.bar.run("xdg-open https://www.fiawec.com/en/") }
        }
      }

      Column {
        width: parent.width
        visible: root.activeTab === "standings"
        spacing: Style.space(10)

        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: [
              { id: "manufacturers", label: "HYPERCAR MFRS", compactLabel: "MFRS" },
              { id: "hypercarDrivers", label: "HYPERCAR DRIVERS", compactLabel: "HCAR" },
              { id: "lmgt3Teams", label: "LMGT3 TEAMS", compactLabel: "TEAMS" },
              { id: "lmgt3Drivers", label: "LMGT3 DRIVERS", compactLabel: "DRIVERS" }
            ]
            delegate: Rectangle {
              required property var modelData
              implicitWidth: categoryLabel.implicitWidth + Style.space(16)
              implicitHeight: Style.space(25)
              radius: Style.space(3)
              color: root.standingsTab === modelData.id ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
              border.width: 1
              border.color: root.standingsTab === modelData.id ? root.fg : root.dim
              Text {
                id: categoryLabel
                anchors.centerIn: parent
                text: root.veryCompactLayout ? modelData.compactLabel : modelData.label
                color: root.standingsTab === modelData.id ? root.fg : root.dim
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: 11
                font.bold: true
              }
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.standingsTab = modelData.id
                  root.showAllStandings = false
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: root.standingsTitle()
          elide: Text.ElideRight
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 17
          font.bold: true
        }

        Text {
          width: parent.width
          text: "2026 FIA World Endurance Championship"
          elide: Text.ElideRight
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 13
        }

        PanelSeparator { width: parent.width }

        Repeater {
          model: root.visibleStandings()

          delegate: Row {
            required property var modelData
            width: parent.width
            height: root.veryCompactLayout ? Style.space(56) : Style.space(38)

            Text { width: root.veryCompactLayout ? Style.space(28) : Style.space(46); height: parent.height; text: "P" + modelData.position; verticalAlignment: Text.AlignVCenter; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
            Column {
              width: Math.max(0, parent.width - (root.veryCompactLayout ? Style.space(76) : Style.space(130)))
              anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15; font.bold: modelData.position === 1 }
              Text { width: parent.width; visible: Boolean(modelData.detail); text: modelData.detail || ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
            }
            Column {
              width: root.veryCompactLayout ? Style.space(48) : Style.space(84)
              anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; text: modelData.points + " pts"; horizontalAlignment: Text.AlignRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
              Text { width: parent.width; text: root.pointsGap(modelData); horizontalAlignment: Text.AlignRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 11 }
            }
          }
        }

        Rectangle {
          visible: (root.standings[root.standingsTab] || []).length > 10
          implicitWidth: moreLabel.implicitWidth + Style.space(18)
          implicitHeight: Style.space(27)
          radius: Style.space(3)
          color: "transparent"
          border.width: 1
          border.color: root.dim
          Text {
            id: moreLabel
            anchors.centerIn: parent
            text: root.showAllStandings ? "SHOW TOP 10" : "SHOW " + ((root.standings[root.standingsTab] || []).length - 10) + " MORE"
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 11
            font.bold: true
          }
          MouseArea { anchors.fill: parent; onClicked: root.showAllStandings = !root.showAllStandings }
        }

        PanelSeparator { width: parent.width }

        Row {
          width: parent.width
          Text {
            width: Math.max(0, parent.width - standingsLink.implicitWidth - Style.space(12))
            text: root.standingsSourceText()
            elide: Text.ElideRight
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 12
          }
          Text {
            id: standingsLink
            text: "OPEN FIA WEC ↗"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 12
            font.bold: true
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.bar) root.bar.run("xdg-open https://www.fiawec.com/en/page/manufacturers-classification")
            }
          }
        }
      }

      Column {
        width: parent.width
        visible: root.activeTab === "settings"
        spacing: Style.space(14)

        Row {
          spacing: Style.space(8)
          PanelActionButton {
            iconText: "󰅁"
            tooltipText: "Back to race weekend"
            foreground: root.fg
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            size: Style.space(28)
            bordered: true
            onClicked: root.activeTab = "weekend"
          }
          Text {
            height: Style.space(28)
            verticalAlignment: Text.AlignVCenter
            text: "SETTINGS"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 17
            font.bold: true
          }
        }

        Text {
          width: parent.width
          text: "Preferences are saved to your Omarchy bar layout."
          wrapMode: Text.WordWrap
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 13
        }

        PanelSeparator { width: parent.width }

        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
           Text { width: Math.max(0, parent.width - flagsToggle.width); text: "SHOW RACE FLAGS"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
            Rectangle {
              id: flagsToggle
              width: Style.space(52)
              height: Style.space(25)
              radius: Style.space(3)
              color: root.showRaceFlags ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
              border.width: 1
              border.color: root.showRaceFlags ? root.fg : root.dim
              Text { anchors.centerIn: parent; text: root.showRaceFlags ? "ON" : "OFF"; color: root.showRaceFlags ? root.fg : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 11; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.persistSettings({ showRaceFlags: !root.showRaceFlags }) }
            }
          }
          Text { width: parent.width; text: "Display event-country flags in the weekend view."; wrapMode: Text.WordWrap; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
           Text { width: Math.max(0, parent.width - completedToggle.width); text: "SHOW COMPLETED SESSIONS"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
            Rectangle {
              id: completedToggle
              width: Style.space(52)
              height: Style.space(25)
              radius: Style.space(3)
              color: root.showCompletedSessions ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
              border.width: 1
              border.color: root.showCompletedSessions ? root.fg : root.dim
              Text { anchors.centerIn: parent; text: root.showCompletedSessions ? "ON" : "OFF"; color: root.showCompletedSessions ? root.fg : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 11; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.persistSettings({ showCompletedSessions: !root.showCompletedSessions }) }
            }
          }
          Text { width: parent.width; text: "Keep completed practice and qualifying sessions visible."; wrapMode: Text.WordWrap; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
        }

      }
    }
    }
  }
}
