"""IT 3007 Lab 4 - a tiny web app that counts visits in PostgreSQL."""
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

OWNER = os.environ.get("OWNER", "unknown")
DATABASE_URL = os.environ.get("DATABASE_URL")


def count_visit():
    if not DATABASE_URL:
        return "n/a (no database)"
    import psycopg
    with psycopg.connect(DATABASE_URL) as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS visits (id serial PRIMARY KEY)")
        conn.execute("INSERT INTO visits DEFAULT VALUES")
        return conn.execute("SELECT count(*) FROM visits").fetchone()[0]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            visits = count_visit()
        except Exception as error:
            visits = f"error ({error.__class__.__name__})"
        body = f"owner={OWNER} served-by={socket.gethostname()} visits={visits}\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())


if __name__ == "__main__":
    print("Listening on port 8000", flush=True)
    HTTPServer(("", 8000), Handler).serve_forever()
