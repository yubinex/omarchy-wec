import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
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
  property var weekendDetails: ({})
  property string weekendSlug: ""
  readonly property string barDisplay: setting("barDisplay", "full") === "compact" ? "status" : setting("barDisplay", "full")

  readonly property var nextRace: {
    for (var i = 0; i < races.length; ++i) {
      // Race start times are not consistently present in the calendar, so
      // retain an event through its local race day rather than guessing a time.
      if (raceEnd(races[i]) >= nowMs) return races[i]
    }
    return null
  }
  readonly property var nextSession: {
    var details = nextRace && nextRace.slug ? weekendDetails[nextRace.slug] : null
    var currentSessions = details ? details.sessions : []
    for (var i = 0; i < currentSessions.length; ++i) {
      var session = currentSessions[i]
      if (session.officialStatus === "EventCompleted") continue
      var start = Date.parse(session.start)
      if (nowMs >= start)
        return { short: sessionShort(session.name), start: session.start, live: true }
      if (nowMs < start) return { short: sessionShort(session.name), start: session.start, live: false }
    }
    return null
  }
  readonly property string label: nextSession ? "WEC " + nextSession.short + " " + sessionCountdown(nextSession)
    : nextRace ? "WEC RACE " + countdown(nextRace) : "WEC —"
  readonly property string tooltip: nextRace
    ? nextSession ? nextRace.name + " · " + nextSession.short + " " + sessionCountdown(nextSession)
      : nextRace.name + " · " + displayDate(nextRace.date) + " · " + countdown(nextRace)
    : "No upcoming WEC race"
  readonly property string displayText: {
    if (barDisplay === "icon" || barDisplay === "status") return ""
    if (vertical) return "WEC"
    if (barDisplay === "compact") {
      if (nextSession) return "WEC · " + sessionCountdown(nextSession)
      return nextRace ? "WEC · " + countdown(nextRace) : "WEC"
    }
    return label
  }
  readonly property color logoColor: {
    var foreground = bar ? bar.barForeground : Color.foreground
    if (barDisplay !== "status" || !nextSession) return foreground
    if (nextSession.live) return "#df5b5b"
    if (Date.parse(nextSession.start) - nowMs <= 2 * 60 * 60 * 1000) return "#e0b84f"
    return foreground
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
      // The official event status, not a guessed race duration, determines
      // when we advance to the following calendar round.
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
    var details = race.slug ? weekendDetails[race.slug] : null
    var sessions = details ? details.sessions : []
    for (var i = 0; i < sessions.length; ++i) {
      if (sessions[i].name === "Race") return Date.parse(sessions[i].start)
    }
    return 0
  }

  function countdown(race) {
    var start = raceStartMs(race)
    if (start) {
      var remaining = start - nowMs
      if (remaining <= 0) return "live"
      if (remaining < 86400000) {
        var minutes = Math.ceil(remaining / 60000)
        return "in " + Math.floor(minutes / 60) + "h " + (minutes % 60) + "m"
      }
    }
    var days = calendarDaysUntil(race)
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
    if (session.live) return "LIVE"
    var minutes = Math.max(0, Math.ceil((start - nowMs) / 60000))
    if (minutes < 60) return "IN " + minutes + "M"
    return "IN " + Math.floor(minutes / 60) + "H " + (minutes % 60) + "M"
  }

  function sessionShort(name) {
    if (name === "Race") return "RACE"
    if (name.indexOf("Free Practice") === 0) return "FP" + name.replace(/\D/g, "")
    if (name.indexOf("Hyperpole") === 0) return "HYPER"
    if (name.indexOf("Qualifying") === 0) return "QUAL"
    return name.toUpperCase()
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
    var re = /href="\/en\/race\/([a-z0-9-]+)-(20\d{2})"[\s\S]{0,500}?flag:([A-Z]{2})[\s\S]{0,900}?<strong[^>]*>\s*(\d{1,2})\s*<\/strong>\s*<small[^>]*>\s*([A-Za-z]{3})/g
    var months = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 }
    var match
    while ((match = re.exec(html)) !== null) {
      if (match[1].indexOf("official-prologue-") === 0) continue
      var month = months[match[5]]
      if (month === undefined) continue
      var day = Number(match[4])
      if (day < 1 || day > 31) continue
      var date = match[2] + "-" + (month + 1 < 10 ? "0" : "") + (month + 1) + "-" + (day < 10 ? "0" : "") + day
      var key = match[1] + ":" + date
      // The official page contains the calendar in both desktop and mobile
      // navigation. Keep one copy of each event.
      if (seen[key]) continue
      seen[key] = true
      parsed.push({ name: titleFromSlug(match[1]), date: date, slug: match[1] + "-" + match[2], countryCode: match[3] })
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
      while ((cell = cellRe.exec(rows[i])) !== null) {
        cells.push(plainText(cell[1]))
      }
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

  function time24(value) {
    var match = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(value)
    if (!match) return value
    var hours = Number(match[1]) % 12 + (match[3].toUpperCase() === "PM" ? 12 : 0)
    return (hours < 10 ? "0" : "") + hours + ":" + match[2]
  }

  function countryCodeFromAddress(address) {
    var countries = { USA: "US", JPN: "JP", Japan: "JP", ESP: "ES", Spain: "ES", ITA: "IT", Italy: "IT", QAT: "QA", Qatar: "QA", GBR: "GB", "United Kingdom": "GB", BEL: "BE", Belgium: "BE", FRA: "FR", France: "FR", BRA: "BR", Brazil: "BR", BHR: "BH", Bahrain: "BH" }
    for (var country in countries) if (address.indexOf(country) >= 0) return countries[country]
    return ""
  }

  function parseWeekend(html, race) {
    var location = /"location"\s*:\s*\{[\s\S]{0,600}?"name"\s*:\s*"([^"]+)"[\s\S]{0,600}?"address"\s*:\s*"([^"]+)"/.exec(html)
    var trackLength = /Length\s*<span[^>]*>\s*([^<]+)\s*<\/span>/.exec(html)
    var turns = /<div[^>]*>\s*(\d+)\s+Turns\s*<span/.exec(html)
    var sessions = []
    var statuses = ({})
    var statusRe = /"@id"\s*:\s*"[^"]+#[^"]+",\s*"name"\s*:\s*"([^"]+)"[\s\S]{0,300}?"eventStatus"\s*:\s*"[^"]*\/([^"]+)"/g
    var statusMatch
    var suffix = " - " + race.name
    while ((statusMatch = statusRe.exec(html)) !== null) {
      var name = statusMatch[1]
      if (name.slice(-suffix.length) === suffix) name = name.slice(0, -suffix.length)
      statuses[name] = statusMatch[2]
    }
    var re = /<div[^>]*class="fw-bold lh-sm"[^>]*>\s*([^<]+)\s*<\/div>[\s\S]{0,800}?data-local="([^"]+)"[^>]*data-timestamp="(\d+)"/g
    var match
    while ((match = re.exec(html)) !== null) {
      var ms = Number(match[3]) * 1000
      var sessionName = plainText(match[1])
      sessions.push({ day: Qt.formatDate(new Date(ms), "ddd d MMM"), name: sessionName, time: time24(match[2]), start: new Date(ms).toISOString(), officialStatus: statuses[sessionName] || "" })
    }
    if (!location || !sessions.length) return null
    var year = race.date.slice(0, 4)
    var round = 0
    for (var i = 0; i < races.length; ++i) if (races[i].date.slice(0, 4) === year && races[i].date <= race.date) ++round
    var address = plainText(location[2])
    return { venue: plainText(location[1]), location: address, countryCode: countryCodeFromAddress(address), trackLength: trackLength ? plainText(trackLength[1]) : "", turns: turns ? Number(turns[1]) : 0, round: "Round " + round, sessions: sessions }
  }

  function refreshWeekend() {
    if (!nextRace || !nextRace.slug || weekendFetch.running) return
    weekendSlug = nextRace.slug
    weekendFetch.running = true
  }

  function refreshCalendarAndStandings() {
    if (!calendarFetch.running) calendarFetch.running = true
    if (!standingsFetch.running) standingsFetch.running = true
  }

  function weekendRefreshInterval() {
    var details = nextRace && nextRace.slug ? weekendDetails[nextRace.slug] : null
    if (!details || !details.sessions || !details.sessions.length) return 3600000
    for (var i = 0; i < details.sessions.length; ++i) {
      var session = details.sessions[i]
      if (session.officialStatus === "EventCompleted") continue
      // Keep status current from two hours before the next active session.
      return nowMs >= Date.parse(session.start) - 2 * 60 * 60 * 1000 ? 300000 : 3600000
    }
    return 3600000
  }

  function refresh() {
    refreshCalendarAndStandings()
    refreshWeekend()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.races = races
    panelLoader.item.settings = settings
    panelLoader.item.hostWidget = root
    panelLoader.item.nowMs = nowMs
    panelLoader.item.calendarUpdatedMs = calendarUpdatedMs
    if (standings) panelLoader.item.standings = standings
    panelLoader.item.standingsUpdatedMs = standingsUpdatedMs
    panelLoader.item.weekendDetails = weekendDetails
    panelLoader.item.anchorItem = button
    panelLoader.item.bar = bar
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  onRacesChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onNextRaceChanged: refreshWeekend()
  onWeekendDetailsChanged: injectPanel()
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
    onTriggered: root.refreshCalendarAndStandings()
  }

  Timer {
    interval: root.weekendRefreshInterval()
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshWeekend()
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
          root.refreshWeekend()
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

  Process {
    id: weekendFetch
    command: ["curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https", "--max-redirs", "3", "--connect-timeout", "8", "--max-time", "15", "--max-filesize", "1048576", "https://www.fiawec.com/en/race/" + root.weekendSlug]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var race = root.nextRace
        var parsed = race && race.slug === root.weekendSlug ? root.parseWeekend(text, race) : null
        if (parsed) {
          var next = Object.assign({}, root.weekendDetails)
          next[root.weekendSlug] = parsed
          root.weekendDetails = next
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.barDisplay === "icon" || root.barDisplay === "status") ? " " : root.displayText
    labelVisible: root.barDisplay !== "icon" && root.barDisplay !== "status"
    fixedWidth: (root.barDisplay === "icon" || root.barDisplay === "status") ? Style.space(52) : -1
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    Rectangle {
      visible: root.barDisplay === "icon" || root.barDisplay === "status"
      anchors.centerIn: parent
      width: Style.space(44)
      height: Style.space(24)
      color: "transparent"
      // Public-domain WEC logo via Wikimedia Commons.
      Image {
        id: wecLogo
        anchors.fill: parent
        anchors.margins: Style.space(1)
        source: "https://upload.wikimedia.org/wikipedia/commons/4/44/WEC_Logo.svg"
        // The source includes a small championship tagline below the mark;
        // crop it for a legible bar-sized logo.
        sourceClipRect: Qt.rect(0, 0, 250, 70)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: false
      }
      MultiEffect {
        anchors.fill: parent
        anchors.margins: Style.space(1)
        source: wecLogo
        colorization: 1.0
        colorizationColor: root.logoColor
        brightness: 1.0
        visible: wecLogo.status === Image.Ready
      }
    }
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
