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
  property double calendarUpdatedMs: 0
  property double standingsUpdatedMs: 0
  property string activeTab: "weekend"
  property string standingsTab: "manufacturers"
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
      }

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Row {
        width: parent.width
        spacing: Style.space(36)
        visible: root.activeTab === "weekend" && root.nextRace !== null

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

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Column {
        width: parent.width
        visible: root.activeTab === "weekend" && root.nextRace && root.raceDetails(root.nextRace).sessions.length > 0
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
            width: parent.width - Style.space(120)
            text: modelData.name
            color: root.fg
            elide: Text.ElideRight
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: 14
          }
        }
      }

      PanelSeparator { width: parent.width; visible: root.activeTab === "weekend" }

      Text {
        visible: root.activeTab === "weekend"
        text: root.calendarSourceText()
        color: root.dim
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: 12
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
              MouseArea { anchors.fill: parent; onClicked: root.standingsTab = modelData.id }
            }
          }
        }

        Text {
          text: root.standingsTitle()
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 17
          font.bold: true
        }

        Text {
          text: "2026 FIA World Endurance Championship"
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 13
        }

        PanelSeparator { width: parent.width }

        Repeater {
          model: root.standings[root.standingsTab]

          delegate: Row {
            required property var modelData
            width: parent.width
            height: modelData.detail ? Style.space(38) : Style.space(30)

            Text { width: Style.space(46); text: "P" + modelData.position; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14 }
            Column {
              width: parent.width - Style.space(130)
              anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 15; font.bold: modelData.position === 1 }
              Text { visible: Boolean(modelData.detail); text: modelData.detail || ""; color: root.dim; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 12 }
            }
            Text { width: Style.space(84); text: modelData.points + " pts"; horizontalAlignment: Text.AlignRight; color: root.fg; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: 14; font.bold: true }
          }
        }

        PanelSeparator { width: parent.width }

        Text {
          text: root.standingsSourceText()
          color: root.dim
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: 12
        }
      }
    }
    }
  }
}
