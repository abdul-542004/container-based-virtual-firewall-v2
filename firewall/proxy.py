"""
Proxy Server - Intercepts traffic and forwards to backend server
Logs all requests for monitoring
"""
import requests
from flask import Flask, request, Response
import json
import logging
from datetime import datetime
import os

app = Flask(__name__)

# Configuration
SERVER_IP = os.getenv('SERVER_IP', '172.20.0.3')
SERVER_PORT = 5000
REQUESTS_LOG = '/app/logs/requests.jsonl'

# Ensure logs directory exists
os.makedirs('/app/logs', exist_ok=True)

def log_request(client_ip, method, path, status_code, blocked=False):
    """Log request details to JSON log file"""
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'client_ip': client_ip,
        'method': method,
        'path': path,
        'status': status_code,
        'blocked': blocked
    }
    
    # Append to JSON log file for dashboard
    try:
        with open(REQUESTS_LOG, 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
    except Exception as e:
        print(f"Error logging request: {e}")

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def proxy(path):
    """Proxy all requests to backend server"""
    
    # Get client info
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    
    # Build target URL
    target_url = f'http://{SERVER_IP}:{SERVER_PORT}/{path}'
    
    try:
        # Forward the request
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers={key: value for (key, value) in request.headers if key.lower() != 'host'},
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            timeout=10
        )
        
        # Log the request
        log_request(client_ip, request.method, f'/{path}', resp.status_code, blocked=False)
        
        # Build response
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        headers = [(name, value) for (name, value) in resp.raw.headers.items()
                   if name.lower() not in excluded_headers]
        
        response = Response(resp.content, resp.status_code, headers)
        return response
        
    except requests.exceptions.RequestException as e:
        log_request(client_ip, request.method, f'/{path}', 500, blocked=True)
        return Response(f"Error connecting to server: {str(e)}", status=500)

if __name__ == '__main__':
    print("=" * 50)
    print("Proxy Server Starting")
    print(f"Forwarding traffic to: {SERVER_IP}:{SERVER_PORT}")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False)
