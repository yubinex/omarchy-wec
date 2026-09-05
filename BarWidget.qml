import QtQuick
import Quickshell.Io
import qs.Ui

// A deliberately small, read-only calendar widget. The official WEC home page
// is the source of truth; the bundled calendar is only used while offline.
BarWidget {
  id: root
  moduleName: "yubinex.wec"

  property var races: [
    { name: "Lone Star Le Mans", date: "2026-09-06" },
    { name: "6 Hours of Fuji", date: "2026-09-27" },
    { name: "6 Hours of Barcelona", date: "2026-10-18" },
    { name: "6 Hours of Monza", date: "2026-11-08" },
    { name: "Qatar 1812km", date: "2027-03-27" },
    { name: "6 Hours of Imola", date: "2027-04-11" },
    { name: "6 Hours of Silverstone", date: "2027-04-25" },
    { name: "6 Hours of Spa-Francorchamps", date: "2027-05-15" },
    { name: "24 Hours of Le Mans", date: "2027-06-12" },
    { name: "Rolex 6 Hours of São Paulo", date: "2027-07-11" },
    { name: "Lone Star Le Mans", date: "2027-09-12" },
    { name: "6 Hours of Fuji", date: "2027-09-26" },
    { name: "8 Hours of Bahrain", date: "2027-11-06" }
  ]
  property double nowMs: Date.now()
  // Set only after a successful parse of the official calendar response.
  property double calendarUpdatedMs: 0
  property var standings: null
  property double standingsUpdatedMs: 0
  property var currentSessions: [
    { short: "FP1", start: "2026-09-04T11:30:00-05:00", duration: 90 },
    { short: "FP2", start: "2026-09-04T16:00:00-05:00", duration: 90 },
    { short: "FP3", start: "2026-09-05T11:00:00-05:00", duration: 90 },
    { short: "QUAL", start: "2026-09-05T15:00:00-05:00", duration: 90 },
    { short: "RACE", start: "2026-09-06T13:00:00-05:00", duration: 360 }
  ]

  readonly property var nextRace: {
    for (var i = 0; i < races.length; ++i) {
      // Race start times are not consistently present in the calendar, so
      // retain an event through its local race day rather than guessing a time.
      if (raceEnd(races[i]) >= nowMs) return races[i]
    }
    return null
  }
  readonly property var nextSession: {
    for (var i = 0; i < currentSessions.length; ++i) {
      var session = currentSessions[i]
      if (Date.parse(session.start) + session.duration * 60000 >= nowMs) return session
    }
    return null
  }
  readonly property string label: nextSession ? "WEC " + nextSession.short + " " + sessionCountdown(nextSession)
    : nextRace ? "WEC RACE " + countdown(nextRace) : "WEC —"
  readonly property string tooltip: nextRace
    ? nextSession ? nextRace.name + " · " + nextSession.short + " " + sessionCountdown(nextSession)
      : nextRace.name + " · " + displayDate(nextRace.date) + " · " + countdown(nextRace)
    : "No upcoming WEC race"

  function dateMs(iso) {
    var parts = String(iso).split("-")
    return Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12)
  }

  function raceEnd(race) { return dateMs(race.date) + 12 * 60 * 60 * 1000 }

  function countdown(race) {
    var days = Math.ceil(Math.max(0, dateMs(race.date) - nowMs) / 86400000)
    if (days === 0) return "today"
    if (days === 1) return "in 1 day"
    if (days < 14) return "in " + days + " days"
    var weeks = Math.floor(days / 7)
    var remainder = days % 7
    return "in " + weeks + " week" + (weeks === 1 ? "" : "s")
      + (remainder ? ", " + remainder + " day" + (remainder === 1 ? "" : "s") : "")
  }

  function sessionCountdown(session) {
    var start = Date.parse(session.start)
    if (nowMs >= start && nowMs < start + session.duration * 60000) return "LIVE"
    var minutes = Math.max(0, Math.ceil((start - nowMs) / 60000))
    if (minutes < 60) return "IN " + minutes + "M"
    return "IN " + Math.floor(minutes / 60) + "H " + (minutes % 60) + "M"
  }

  function displayDate(iso) {
    var date = new Date(dateMs(iso))
    return Qt.formatDate(date, "ddd d MMM yyyy")
  }

  function titleFromSlug(slug) {
    var names = {
      "lone-star-le-mans": "Lone Star Le Mans",
      "6-hours-of-fuji": "6 Hours of Fuji",
      "6-hours-of-barcelona": "6 Hours of Barcelona",
      "6-hours-of-monza": "6 Hours of Monza",
      "qatar-1812km": "Qatar 1812km",
      "6-hours-of-imola": "6 Hours of Imola",
      "6-hours-of-silverstone": "6 Hours of Silverstone",
      "totalenergies-6-hours-of-spa-francorchamps": "TotalEnergies 6 Hours of Spa-Francorchamps",
      "24-hours-of-le-mans": "24 Hours of Le Mans",
      "rolex-6-hours-of-sao-paulo": "Rolex 6 Hours of São Paulo",
      "bapco-energies-8-hours-of-bahrain": "Bapco Energies 8 Hours of Bahrain"
    }
    return names[slug] || slug.replace(/-/g, " ")
  }

  function parseCalendar(html) {
    var parsed = []
    var seen = ({})
    // Each official race card has its race URL followed by the day and month.
    // Bound the match so a malformed response cannot consume excessive memory.
    var re = /href="\/en\/race\/([a-z0-9-]+)-(20\d{2})"[\s\S]{0,1400}?<strong[^>]*>\s*(\d{1,2})\s*<\/strong>\s*<small[^>]*>\s*([A-Za-z]{3})/g
    var months = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 }
    var match
    while ((match = re.exec(html)) !== null) {
      if (match[1].indexOf("official-prologue-") === 0) continue
      var month = months[match[4]]
      if (month === undefined) continue
      var day = Number(match[3])
      if (day < 1 || day > 31) continue
      var date = match[2] + "-" + (month + 1 < 10 ? "0" : "") + (month + 1) + "-" + (day < 10 ? "0" : "") + day
      var key = match[1] + ":" + date
      // The official page contains the calendar in both desktop and mobile
      // navigation. Keep one copy of each event.
      if (seen[key]) continue
      seen[key] = true
      parsed.push({ name: titleFromSlug(match[1]), date: date })
    }
    parsed.sort(function(a, b) { return a.date.localeCompare(b.date) })
    return parsed
  }

  function plainText(html) {
    return String(html).replace(/<[^>]*>/g, " ").replace(/&amp;/g, "&")
      .replace(/&#x27;/g, "'").replace(/&nbsp;/g, " ").replace(/\s+/g, " ").trim()
  }

  function parseStandingsTable(html, tableId, nameCell, detailCell) {
    var section = new RegExp('id="' + tableId + '"[\\s\\S]*?<tbody>([\\s\\S]*?)</tbody>').exec(html)
    if (!section) return []
    var rows = section[1].match(/<tr>[\s\S]*?<\/tr>/g) || []
    var parsed = []
    for (var i = 0; i < rows.length; ++i) {
      var cells = []
      var cellRe = /<td\b[^>]*>([\s\S]*?)<\/td>/g
      var cell
      while ((cell = cellRe.exec(rows[i])) !== null) cells.push(plainText(cell[1]))
      var position = Number(cells[0])
      var name = cells[nameCell]
      var points = Number(cells[cells.length - 1])
      if (!position || !name || isNaN(points)) continue
      var entry = { position: position, name: name, points: points }
      if (detailCell >= 0 && cells[detailCell]) entry.detail = cells[detailCell]
      parsed.push(entry)
    }
    return parsed
  }

  function parseStandings(html) {
    var parsed = {
      manufacturers: parseStandingsTable(html, "results-65", 1, -1),
      hypercarDrivers: parseStandingsTable(html, "results-55", 3, 2),
      lmgt3Teams: parseStandingsTable(html, "results-73", 3, 2),
      lmgt3Drivers: parseStandingsTable(html, "results-72", 3, 2)
    }
    return parsed.manufacturers.length && parsed.hypercarDrivers.length
      && parsed.lmgt3Teams.length && parsed.lmgt3Drivers.length ? parsed : null
  }

  function refresh() {
    if (!calendarFetch.running) calendarFetch.running = true
    if (!standingsFetch.running) standingsFetch.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.races = races
    panelLoader.item.nowMs = nowMs
    panelLoader.item.calendarUpdatedMs = calendarUpdatedMs
    if (standings) panelLoader.item.standings = standings
    panelLoader.item.standingsUpdatedMs = standingsUpdatedMs
    panelLoader.item.anchorItem = button
    panelLoader.item.bar = bar
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  onRacesChanged: injectPanel()
  onNowMsChanged: injectPanel()
  onCalendarUpdatedMsChanged: injectPanel()
  onStandingsChanged: injectPanel()
  onStandingsUpdatedMsChanged: injectPanel()
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: root.injectPanel()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: calendarFetch
    command: ["curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https", "--max-redirs", "3", "--connect-timeout", "8", "--max-time", "15", "--max-filesize", "1048576", "https://www.fiawec.com/en/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var parsed = root.parseCalendar(text)
        if (parsed.length > 0) {
          root.races = parsed
          root.calendarUpdatedMs = Date.now()
        }
      }
    }
  }

  Process {
    id: standingsFetch
    command: ["curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https", "--max-redirs", "3", "--connect-timeout", "8", "--max-time", "15", "--max-filesize", "1048576", "https://www.fiawec.com/en/page/manufacturers-classification"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var parsed = root.parseStandings(text)
        if (parsed) {
          root.standings = parsed
          root.standingsUpdatedMs = Date.now()
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "WEC" : root.label
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.refresh()
      else if (button === Qt.LeftButton) root.togglePanel()
      else if (button === Qt.RightButton && root.bar) root.bar.run("xdg-open https://www.fiawec.com/en/")
    }
    Accessible.role: Accessible.Button
    Accessible.name: "WEC Upcoming"
    Accessible.description: root.tooltip
  }
}
