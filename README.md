# Omarchy WEC

An Omarchy bar plugin for upcoming FIA World Endurance Championship events.

It shows the next race or active weekend session in the bar. Click the widget
for the event panel, which includes the race countdown, venue, format, weekend
schedule when available, and upcoming races.

## Data sources

- Calendar and event data: [FIA WEC](https://www.fiawec.com/)
- The plugin only makes bounded HTTPS requests to the official calendar.

## Install for development

Omarchy discovers user plugins at `~/.config/omarchy/plugins/<plugin-id>/`.
Use a symlink so the running plugin points to this checkout:

```bash
ln -s ~/Projects/omarchy-wec ~/.config/omarchy/plugins/yubinex.wec
```

The shell reloads the plugin when files change. If needed, run:

```bash
omarchy restart shell
```

## Controls

- Left click: open or close the event panel
- Middle click: refresh the calendar
- Right click: open the official FIA WEC site

## License

[MIT](LICENSE)
