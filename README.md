# Stock Helper RR

Windows-friendly local trackers with tiny Python servers.

## Stock tracker

Public static site:

`https://liyanghusky.github.io/stockhelperrr/`

Open `outputs/open-stock-five.bat` on Windows. It starts the stock server and opens:

`http://127.0.0.1:8765/`

You can also run it manually:

```bash
py server.py
```

Stock features:

- Add and remove stock symbols
- Switch ranges: 1D, 1W, 1M, 3M, 1Y
- 2 visual systems: Harkonnen and Wabi-Sabi
- Offline deterministic demo data, no API key required

## World Cup tracker

Open `outputs/open-worldcup-tracker.bat` on Windows. It starts the World Cup server and opens:

`http://127.0.0.1:8766/`

You can also run it manually:

```bash
py server_worldcup.py
```

World Cup features:

- 48-team list
- Group standings
- Match schedule with local kick-off times
- Venue and broadcast labels when provided
- Search, group filter, status filter and refresh
