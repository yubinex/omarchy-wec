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
  readonly property bool showRaceFlags: setting("showRaceFlags", true)
  readonly property bool showCompletedSessions: setting("showCompletedSessions", true)
  readonly property string selectedBarDisplay: setting("barDisplay", "full") === "compact" ? "status" : setting("barDisplay", "full")
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

  function sessionStatus(session) {
    var start = Date.parse(session.start)
    if (session.officialStatus === "EventCompleted") return "DONE"
    if (nowMs >= start) return "LIVE"
    var minutes = Math.ceil((start - nowMs) / 60000)
    var hours = Math.floor(minutes / 60)
    return "IN " + twoDigits(hours) + "H " + twoDigits(minutes % 60) + "M"
  }

  function twoDigits(value) { return value < 10 ? "0" + value : String(value) }

  // A laptop can fit the panel but not the desktop-sized monospace schedule.
  // Scale text from the available row width while preserving a readable floor.
  function compactFontSize(width, maximum, minimum, widthPerPixel) {
    return Math.max(minimum, Math.min(maximum, Math.floor(width / widthPerPixel)))
  }

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
    centerOnBar: true
    // Preserve the 520px desktop design, but never exceed the work area on
    // smaller or high-DPI displays.
    contentWidth: popup.fittedContentWidth(Style.space(520))
    // KeyboardPanel accounts for the display work area. It uses natural size
    // until needed content would exceed the available screen height.
    contentHeight: popup.fittedContentHeight(content.implicitHeight + Style.space(48))

    Flickable {
      id: scroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight + Style.space(48)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
      id: content
      x: Style.space(24)
      y: Style.space(24)
      width: scroll.width - Style.space(48)
      spacing: Style.space(12)

      Text {
        text: root.activeTab === "settings" ? "WEC PLUGIN" : "FIA WORLD ENDURANCE CHAMPIONSHIP"
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Row {
        width: parent.width
        visible: root.activeTab !== "settings"
        readonly property real flagAreaWidth: root.showRaceFlags ? Math.min(Style.space(128), width * 0.28) : 0
        Text {
          width: parent.width - parent.flagAreaWidth
          text: root.nextRace ? root.nextRace.name : "No upcoming race"
          elide: Text.ElideRight
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 24
          font.bold: true
        }
        Text {
          width: parent.flagAreaWidth
          height: parent.height
          text: root.nextRace ? root.raceFlag(root.nextRace) : ""
          visible: root.showRaceFlags
          horizontalAlignment: Text.AlignRight
          verticalAlignment: Text.AlignVCenter
          font.pixelSize: Math.min(Style.space(72), parent.flagAreaWidth * 0.72)
        }
      }

      Text {
        visible: root.activeTab !== "settings" && root.nextRace !== null
        text: root.nextRace ? root.dateText(root.nextRace) : ""
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 15
      }

      Text {
        visible: root.activeTab !== "settings" && root.nextRace !== null
        text: root.nextRace ? root.longCountdown(root.nextRace) : ""
        color: root.fg
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 18
        font.bold: true
      }

      Row {
        spacing: Style.space(8)

        Repeater {
          model: [
            { id: "weekend", label: "RACE WEEKEND" },
            { id: "standings", label: "STANDINGS" }
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
              text: modelData.label
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

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Row {
        width: parent.width
        spacing: Style.space(36)
        visible: root.activeTab === "weekend" && root.nextRace !== null

        Column {
          id: venueDetails
          width: parent.width * 0.62
          spacing: Style.space(4)
          Text { text: "VENUE"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
          Text { width: parent.width; text: root.nextRace ? root.raceDetails(root.nextRace).venue : ""; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15 }
          Text { width: parent.width; text: root.nextRace ? root.raceDetails(root.nextRace).location : ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
        }
        Column {
          width: parent.width - parent.spacing - venueDetails.width
          spacing: Style.space(4)
          Text { text: "TRACK"; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12; font.bold: true }
          Text { width: parent.width; text: root.nextRace ? root.raceDetails(root.nextRace).trackLength : ""; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15 }
          Text { width: parent.width; text: root.nextRace && root.raceDetails(root.nextRace).turns ? root.raceDetails(root.nextRace).turns + " turns" : ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
        }
      }

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Column {
        width: parent.width
        visible: root.activeTab === "weekend" && root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0
        spacing: Style.space(7)
        Text { width: parent.width; text: "WEEKEND SCHEDULE · LOCAL TIME (" + root.localTimeZone() + ")"; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 12, 10, 42); font.bold: true }
        Repeater {
          model: root.nextRace ? root.visibleSessions(root.nextRace) : []
          delegate: Row {
            required property var modelData
            width: parent.width
            opacity: root.sessionStatus(modelData) === "DONE" ? 0.45 : 1.0
            Text { id: sessionDay; width: Math.min(Style.space(100), parent.width * 0.25); text: Qt.formatDate(new Date(modelData.start), "ddd d MMM"); elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 14, 11, 36) }
            Text { width: Math.max(0, parent.width - sessionDay.width - sessionTime.width - sessionStatusText.width); text: modelData.name; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 14, 11, 36) }
            Text { id: sessionTime; width: Math.min(Style.space(60), parent.width * 0.18); text: Qt.formatTime(new Date(modelData.start), "HH:mm"); horizontalAlignment: Text.AlignRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 14, 11, 36); font.bold: modelData.name === "Race" }
            Text { id: sessionStatusText; width: Math.min(Style.space(70), parent.width * 0.22); text: root.sessionStatus(modelData); horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; color: root.sessionStatusColor(modelData); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 12, 9, 50); font.bold: true }
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
            width: Style.space(108)
            text: Qt.formatDate(new Date(root.dateMs(modelData.date)), "d MMM yyyy")
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
          Text {
            width: root.showRaceFlags ? Style.space(28) : 0
            text: root.raceFlag(modelData)
            visible: root.showRaceFlags
            font.pixelSize: 16
          }
          Text {
            width: parent.width - Style.space(120) - (root.showRaceFlags ? Style.space(28) : 0)
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
          visible: root.activeTab === "weekend"
          Text {
            width: parent.width - calendarLink.implicitWidth - Style.space(12)
            text: root.calendarSourceText()
            elide: Text.ElideRight
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.compactFontSize(parent.width, 12, 9, 45)
          }
          Text {
            id: calendarLink
            text: "OPEN FIA WEC ↗"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.compactFontSize(parent.width, 12, 9, 45)
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
        visible: root.activeTab === "standings"
        spacing: Style.space(10)

        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: [
              { id: "manufacturers", label: "HYPERCAR MFRS" },
              { id: "hypercarDrivers", label: "HYPERCAR DRIVERS" },
              { id: "lmgt3Teams", label: "LMGT3 TEAMS" },
              { id: "lmgt3Drivers", label: "LMGT3 DRIVERS" }
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
                text: modelData.label
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
          text: root.standingsTitle()
          width: parent.width
          elide: Text.ElideRight
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.compactFontSize(parent.width, 17, 13, 30)
          font.bold: true
        }

        Text {
          text: "2026 FIA World Endurance Championship"
          width: parent.width
          elide: Text.ElideRight
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.compactFontSize(parent.width, 13, 10, 40)
        }

        PanelSeparator { width: parent.width }

        Repeater {
          model: root.visibleStandings()

          delegate: Row {
            required property var modelData
            width: parent.width
            height: Style.space(38)

            Text { id: standingsRank; width: Math.min(Style.space(46), parent.width * 0.11); height: parent.height; text: "P" + modelData.position; verticalAlignment: Text.AlignVCenter; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 14, 10, 38) }
            Column {
              width: parent.width - standingsRank.width - standingsPoints.width
              anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 15, 11, 32); font.bold: modelData.position === 1 }
              Text { width: parent.width; visible: Boolean(modelData.detail); text: modelData.detail || ""; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 12, 9, 38) }
            }
            Column {
              id: standingsPoints
              width: Math.min(Style.space(84), parent.width * 0.2)
              anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; text: modelData.points + " pts"; horizontalAlignment: Text.AlignRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 14, 10, 38); font.bold: true }
              Text { width: parent.width; text: root.pointsGap(modelData); horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.compactFontSize(parent.width, 11, 8, 45) }
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
            width: parent.width - standingsLink.implicitWidth - Style.space(12)
            text: root.standingsSourceText()
            elide: Text.ElideRight
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.compactFontSize(parent.width, 12, 9, 45)
          }
          Text {
            id: standingsLink
            text: "OPEN FIA WEC ↗"
            color: root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.compactFontSize(parent.width, 12, 9, 45)
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
          text: "Preferences are saved to your Omarchy bar layout."
          width: parent.width
          elide: Text.ElideRight
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 13
        }

        PanelSeparator { width: parent.width }

        Row {
          width: parent.width
          height: Style.space(42)
          Column {
            width: parent.width - flagsToggle.width
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: "SHOW RACE FLAGS"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
            Text { width: parent.width; text: "Display event-country flags in the weekend view."; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
          }
          Rectangle {
            id: flagsToggle
            width: Style.space(52)
            height: Style.space(25)
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.space(3)
            color: root.showRaceFlags ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
            border.width: 1
            border.color: root.showRaceFlags ? root.fg : root.dim
            Text { anchors.centerIn: parent; text: root.showRaceFlags ? "ON" : "OFF"; color: root.showRaceFlags ? root.fg : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.persistSettings({ showRaceFlags: !root.showRaceFlags }) }
          }
        }

        Row {
          width: parent.width
          height: Style.space(42)
          Column {
            width: parent.width - completedToggle.width
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: "SHOW COMPLETED SESSIONS"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
            Text { width: parent.width; text: "Keep completed practice and qualifying sessions visible."; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
          }
          Rectangle {
            id: completedToggle
            width: Style.space(52)
            height: Style.space(25)
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.space(3)
            color: root.showCompletedSessions ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
            border.width: 1
            border.color: root.showCompletedSessions ? root.fg : root.dim
            Text { anchors.centerIn: parent; text: root.showCompletedSessions ? "ON" : "OFF"; color: root.showCompletedSessions ? root.fg : root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.persistSettings({ showCompletedSessions: !root.showCompletedSessions }) }
          }
        }

        Row {
          width: parent.width
          height: Style.space(42)
          Column {
            width: parent.width - displayChoices.width - Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: "BAR DISPLAY"; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
            Text { width: parent.width; text: "Choose the information shown in the bar."; elide: Text.ElideRight; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
          }
          Row {
            id: displayChoices
            spacing: Style.space(5)
            Repeater {
              model: [
                { id: "full", label: "FULL" },
                { id: "icon", label: "LOGO" },
                { id: "status", label: "ALERT" }
              ]
              delegate: Rectangle {
                required property var modelData
                implicitWidth: displayLabel.implicitWidth + Style.space(12)
                implicitHeight: Style.space(25)
                radius: Style.space(3)
                color: root.selectedBarDisplay === modelData.id ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16) : "transparent"
                border.width: 1
                border.color: root.selectedBarDisplay === modelData.id ? root.fg : root.dim
                Text {
                  id: displayLabel
                  anchors.centerIn: parent
                  text: modelData.label
                  color: root.selectedBarDisplay === modelData.id ? root.fg : root.dim
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: 11
                  font.bold: true
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.persistSettings({ barDisplay: modelData.id }) }
              }
            }
          }
        }
      }
    }
    }
  }
}
