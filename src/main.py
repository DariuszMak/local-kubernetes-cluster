import logging
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

logger = logging.getLogger(__name__)

HTML_PAGE = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>python-project</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Syne:wght@700;800&display=swap');

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --bg:      #0b0c10;
      --surface: #13141a;
      --border:  #1e2030;
      --accent:  #c8f135;
      --muted:   #4a4f66;
      --text:    #e8eaf0;
    }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'DM Mono', monospace;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }

    /* subtle grid overlay */
    body::before {
      content: '';
      position: fixed; inset: 0;
      background-image:
        linear-gradient(var(--border) 1px, transparent 1px),
        linear-gradient(90deg, var(--border) 1px, transparent 1px);
      background-size: 48px 48px;
      opacity: .5;
      pointer-events: none;
    }

    .card {
      position: relative;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: 3rem 3.5rem;
      max-width: 520px;
      width: 90vw;
      text-align: center;
      box-shadow: 0 0 80px -20px rgba(200, 241, 53, .12);
    }

    .badge {
      display: inline-block;
      font-size: .65rem;
      letter-spacing: .18em;
      text-transform: uppercase;
      color: var(--accent);
      border: 1px solid var(--accent);
      border-radius: 2px;
      padding: .2em .75em;
      margin-bottom: 1.5rem;
    }

    h1 {
      font-family: 'Syne', sans-serif;
      font-weight: 800;
      font-size: clamp(2rem, 6vw, 3rem);
      letter-spacing: -.02em;
      line-height: 1.1;
      margin-bottom: .5rem;
    }

    h1 span { color: var(--accent); }

    .sub {
      color: var(--muted);
      font-size: .8rem;
      letter-spacing: .05em;
      margin-bottom: 2.5rem;
    }

    .clock-wrap {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 3px;
      padding: 1rem 1.5rem;
    }

    .clock-label {
      font-size: .6rem;
      letter-spacing: .2em;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: .4rem;
    }

    #clock {
      font-size: 1.6rem;
      font-weight: 500;
      letter-spacing: .06em;
      color: var(--accent);
      font-variant-numeric: tabular-nums;
    }

    .dot {
      display: inline-block;
      width: 6px; height: 6px;
      border-radius: 50%;
      background: var(--accent);
      margin-right: .5rem;
      vertical-align: middle;
      animation: pulse 1.4s ease-in-out infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50%       { opacity: .3; transform: scale(.7); }
    }

    /* fade-in on load */
    .card { animation: fadeUp .5s ease both; }
    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(18px); }
      to   { opacity: 1; transform: translateY(0); }
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">python-project &nbsp;/&nbsp; k3d</div>
    <h1>Hello, <span>World</span></h1>
    <p class="sub">Container is healthy &amp; serving requests</p>
    <div class="clock-wrap">
      <div class="clock-label"><span class="dot"></span>current time</div>
      <div id="clock">--:--:--</div>
    </div>
  </div>
  <script>
    function tick() {
      const now = new Date();
      document.getElementById('clock').textContent =
        now.toLocaleTimeString('en-GB', { hour12: false });
    }
    tick();
    setInterval(tick, 1000);
  </script>
</body>
</html>
"""


def load_dev_env(env_path: str = ".dev.env") -> dict[str, str]:
    """Load key=value pairs from a .env file into os.environ. Returns loaded vars."""
    loaded: dict[str, str] = {}
    path = Path(env_path)
    if not path.exists():
        logger.warning("Env file not found: %s", env_path)
        return loaded
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip()
            if os.getenv(key) is None:
                os.environ[key] = value
                logger.debug("Loaded env var: %s=%s", key, value)
            else:
                logger.debug("Skipped env var (already set): %s=%s", key, value)
            loaded[key] = value
    logger.info("Loaded %d var(s) from %s", len(loaded), env_path)
    return loaded


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        body = HTML_PAGE.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:  # noqa: ANN002
        logger.info(fmt, *args)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    load_dev_env()
    host = os.getenv("HOST", "0.0.0.0")  # noqa: S104
    port = int(os.getenv("PORT", "8000"))
    server = HTTPServer((host, port), Handler)
    # Always print a localhost URL regardless of bind address so it's clickable locally
    logger.info("Serving on http://%s:%d  →  open http://localhost:%d", host, port, port)
    server.serve_forever()