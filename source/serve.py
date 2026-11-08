# Local web server for Play HoMo-LAP.bat: serves the folder it is started in (game\) on port 8765.
# Like "python -m http.server", but tells the browser to check for a newer file on every load
# (Cache-Control: no-cache), so a rebuilt index.html is never replaced by an old cached copy.
import http.server, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()
    def log_message(self, *args):
        pass

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
http.server.ThreadingHTTPServer(('', port), Handler).serve_forever()
