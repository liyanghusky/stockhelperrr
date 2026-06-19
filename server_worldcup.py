from datetime import datetime, timedelta, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen
import json
import mimetypes
import os
import socket
import sys
import time
import webbrowser


ROOT = Path(__file__).resolve().parent
OUTPUTS = ROOT / "outputs"
HOST = "127.0.0.1"
DEFAULT_PORT = 8766
CACHE_SECONDS = 180

TEAMS_URL = "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/teams"
STANDINGS_URL = (
    "https://site.web.api.espn.com/apis/v2/sports/soccer/fifa.world/standings"
    "?region=us&lang=en&contentorigin=espn&type=0&level=3&sort=rank:asc"
)
SCOREBOARD_URL = "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates={date}"

_cache = {"time": 0, "payload": None}


def fetch_json(url):
    req = Request(url, headers={"User-Agent": "StockHelperRR/1.0"})
    with urlopen(req, timeout=18) as response:
        return json.loads(response.read().decode("utf-8"))


def logo_for(team):
    logos = team.get("logos") or []
    if logos:
        return logos[0].get("href")
    return team.get("logo")


def compact_team(team):
    return {
        "id": team.get("id"),
        "name": team.get("displayName") or team.get("name"),
        "shortName": team.get("shortDisplayName") or team.get("abbreviation"),
        "abbr": team.get("abbreviation"),
        "slug": team.get("slug"),
        "color": team.get("color"),
        "logo": logo_for(team),
    }


def stat_map(entry):
    stats = {}
    for stat in entry.get("stats", []):
        name = stat.get("name")
        if name:
            stats[name] = stat.get("displayValue", "")
    return stats


def transform_standings(data):
    groups = []
    for child in data.get("children", []):
        table = []
        standings = child.get("standings", {})
        for entry in standings.get("entries", []):
            team = compact_team(entry.get("team", {}))
            stats = stat_map(entry)
            table.append({
                "team": team,
                "played": stats.get("gamesPlayed", "0"),
                "wins": stats.get("wins", "0"),
                "draws": stats.get("ties", "0"),
                "losses": stats.get("losses", "0"),
                "goalsFor": stats.get("pointsFor", "0"),
                "goalsAgainst": stats.get("pointsAgainst", "0"),
                "goalDiff": stats.get("pointDifferential", "0"),
                "points": stats.get("points", "0"),
                "advanced": stats.get("advanced", ""),
            })
        groups.append({
            "id": child.get("id"),
            "name": child.get("name"),
            "teams": table,
        })
    return groups


def transform_match(event):
    competition = (event.get("competitions") or [{}])[0]
    status = competition.get("status", {}).get("type", {})
    competitors = competition.get("competitors", [])
    home = next((item for item in competitors if item.get("homeAway") == "home"), competitors[0] if competitors else {})
    away = next((item for item in competitors if item.get("homeAway") == "away"), competitors[1] if len(competitors) > 1 else {})
    venue = competition.get("venue", {})
    group = (competition.get("altGameNote") or "").replace("FIFA World Cup, ", "")
    broadcasts = []
    for item in competition.get("broadcasts", []):
        broadcasts.extend(item.get("names", []))

    return {
        "id": event.get("id"),
        "name": event.get("name"),
        "shortName": event.get("shortName"),
        "date": event.get("date"),
        "group": group or event.get("season", {}).get("slug", "World Cup"),
        "state": status.get("state"),
        "status": status.get("description"),
        "detail": status.get("detail"),
        "completed": status.get("completed", False),
        "venue": venue.get("fullName"),
        "city": (venue.get("address") or {}).get("city"),
        "broadcasts": sorted(set(broadcasts)),
        "home": {
            **compact_team(home.get("team", {})),
            "score": home.get("score", "0"),
            "winner": home.get("winner", False),
        },
        "away": {
            **compact_team(away.get("team", {})),
            "score": away.get("score", "0"),
            "winner": away.get("winner", False),
        },
    }


def date_codes():
    today = datetime.now(timezone.utc).date()
    for offset in range(-2, 15):
        yield (today + timedelta(days=offset)).strftime("%Y%m%d")


def build_payload():
    errors = []

    try:
        teams_raw = fetch_json(TEAMS_URL)
        teams = [
            compact_team(item.get("team", {}))
            for item in teams_raw.get("sports", [{}])[0].get("leagues", [{}])[0].get("teams", [])
        ]
        teams = sorted(teams, key=lambda item: item.get("name") or "")
    except (URLError, TimeoutError, KeyError, IndexError, json.JSONDecodeError) as exc:
        teams = []
        errors.append(f"teams: {exc}")

    try:
        groups = transform_standings(fetch_json(STANDINGS_URL))
    except (URLError, TimeoutError, KeyError, IndexError, json.JSONDecodeError) as exc:
        groups = []
        errors.append(f"standings: {exc}")

    matches = []
    seen = set()
    for code in date_codes():
        try:
            board = fetch_json(SCOREBOARD_URL.format(date=code))
        except (URLError, TimeoutError, json.JSONDecodeError) as exc:
            errors.append(f"scoreboard {code}: {exc}")
            continue
        for event in board.get("events", []):
            if event.get("id") in seen:
                continue
            seen.add(event.get("id"))
            matches.append(transform_match(event))

    matches.sort(key=lambda item: item.get("date") or "")
    return {
        "source": {
            "provider": "ESPN public soccer API",
            "fifaSchedule": "https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/scores-fixtures",
            "fifaStandings": "https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/standings",
            "generatedAt": datetime.now(timezone.utc).isoformat(),
        },
        "teams": teams,
        "groups": groups,
        "matches": matches,
        "errors": errors,
    }


def payload():
    now = time.time()
    if _cache["payload"] and now - _cache["time"] < CACHE_SECONDS:
        return _cache["payload"]
    _cache["payload"] = build_payload()
    _cache["time"] = now
    return _cache["payload"]


class WorldCupHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(OUTPUTS), **kwargs)

    def route_request(self):
        if self.path in {"/", ""}:
            self.path = "/worldcup-tracker.html"
        if self.path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return False
        return True

    def do_GET(self):
        if self.path.startswith("/api/worldcup"):
            body = json.dumps(payload()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if not self.route_request():
            return
        return super().do_GET()

    def do_HEAD(self):
        if not self.route_request():
            return
        return super().do_HEAD()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write("%s - %s\n" % (self.address_string(), fmt % args))


def find_port(start):
    port = start
    while port < start + 50:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind((HOST, port))
            except OSError:
                port += 1
                continue
        return port
    raise RuntimeError("Could not find an open local port.")


def main():
    mimetypes.add_type("text/html; charset=utf-8", ".html")
    port = find_port(int(os.environ.get("WORLDCUP_PORT", DEFAULT_PORT)))
    url = f"http://{HOST}:{port}/"
    server = ThreadingHTTPServer((HOST, port), WorldCupHandler)
    print(f"World Cup Tracker running at {url}")
    print("Press Ctrl+C to stop.")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping World Cup Tracker.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
