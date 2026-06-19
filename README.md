# Stock Five

Windows-friendly local stock watchlist prototype with a tiny Python server and 15 visual styles.

Open `outputs/open-stock-five.bat` on Windows. It starts the server and opens:

`http://127.0.0.1:8765/`

You can also run it manually:

```bash
py server.py
```

Features:

- Add and remove stock symbols
- Switch ranges: 1D, 1W, 1M, 3M, 1Y
- 15 themes: Trader, Terminal, Newspaper, Glass, Pastel, Aurora, Ink, Candy, Brutal, Mono, Luxury, Cyber, Zen, Bloom, Cockpit
- Offline deterministic demo data, no API key required
