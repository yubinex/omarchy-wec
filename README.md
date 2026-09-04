# Omarchy WEC

An Omarchy bar plugin for upcoming FIA World Endurance Championship events.

It shows the next race or active weekend session in the bar. Click the widget
for the event panel, which includes the race countdown, venue, format, weekend
schedule when available, and upcoming races.

## Data sources

- Calendar and event data: [FIA WEC](https://www.fiawec.com/)
- The plugin only makes bounded HTTPS requests to the official calendar.

## Installation

Install and enable the plugin with Omarchy:

```bash
omarchy plugin add https://github.com/yubinex/omarchy-wec.git --enable
```

Update it later with:

```bash
omarchy plugin update yubinex.wec --yes
```

## Controls

- Left click: open or close the event panel
- Middle click: refresh the calendar
- Right click: open the official FIA WEC site

## License

[MIT](LICENSE)
