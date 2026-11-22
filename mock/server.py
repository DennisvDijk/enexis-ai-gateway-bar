import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, f, *a): sys.stderr.write(f"{self.command} {self.path} auth={self.headers.get('Authorization')}\n")
    def do_GET(self):
        p=self.path.split('?')[0]
        d={"/health/liveliness":"I'm alive!","/health/readiness":{"status":"healthy","db":"connected"},
        "/v1/models":{"data":[{"id":"gpt-4o"},{"id":"claude-sonnet"}] if 'healthy_only' not in self.path else {"data":[{"id":"gpt-4o"}]}["data"] and {"data":[{"id":"gpt-4o"}]}} if False else None}
        if p=="/v1/models":
            body={"data":[{"id":"gpt-4o"}]} if "healthy_only" in self.path else {"data":[{"id":"gpt-4o"},{"id":"claude-sonnet"}]}
        elif p=="/key/info": body={"info":{"spend":4.2,"max_budget":10,"key_alias":"mock","budget_duration":"30d","budget_reset_at":"2026-12-01T00:00:00+00:00"}}
        elif p=="/spend/logs/v2": body={"data":[{"model":"gpt-4o","spend":1.5}]}
        elif p=="/global/spend": body={"spend":99.5}
        elif p.startswith("/health"): body=d.get(p,"ok")
        else: self.send_response(404); self.end_headers(); return
        b=json.dumps(body).encode(); self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers(); self.wfile.write(b)
HTTPServer(("127.0.0.1",4000),H).serve_forever()
