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
SERVER_IP = os.getenv('SERVER_IP', '172.30.0.3')
SERVER_PORT = 5000
DASHBOARD_URL = 'http://localhost:8080'

def get_client_mac(client_ip):
    """Get MAC address of client from ARP table"""
    try:
        import subprocess
        result = subprocess.run(['arp', '-n', client_ip], capture_output=True, text=True, timeout=1)
        for line in result.stdout.split('\n'):
            if client_ip in line:
                parts = line.split()
                if len(parts) >= 3:
                    mac = parts[2]
                    if mac != '<incomplete>':
                        return mac.lower()
    except:
        pass
    return None

def is_mac_blocked(mac):
    """Check if MAC address is blocked"""
    try:
        response = requests.get(f'{DASHBOARD_URL}/api/blocked_macs', timeout=1)
        if response.status_code == 200:
            data = response.json()
            blocked_macs = [m.lower() for m in data.get('blocked_macs', [])]
            return mac.lower() in blocked_macs
    except:
        pass
    return False

def log_request(client_ip, method, path, status_code, blocked=False, reason=None):
    """Send request details to dashboard in-memory storage"""
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'client_ip': client_ip,
        'method': method,
        'path': path,
        'status': status_code,
        'blocked': blocked
    }
    
    if reason:
        log_entry['reason'] = reason
    
    # Send to dashboard API
    try:
        requests.post(f'{DASHBOARD_URL}/api/log', json=log_entry, timeout=1)
    except Exception as e:
        print(f"Error logging request: {e}")

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def proxy(path):
    """Proxy all requests to backend server"""
    
    # Get client info
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    
    # Check if client MAC is blocked
    client_mac = get_client_mac(client_ip)
    if client_mac and is_mac_blocked(client_mac):
        # Log the blocked attempt
        log_request(client_ip, request.method, f'/{path}', 403, blocked=True, reason=f"MAC address blocked: {client_mac}")
        print(f"[BLOCKED] MAC {client_mac} (IP: {client_ip}) attempted to access /{path}")
        return Response("Access Denied: MAC address blocked", status=403)
    
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
        log_request(client_ip, request.method, f'/{path}', 500, blocked=True, reason=f"Server connection error")
        return Response(f"Error connecting to server: {str(e)}", status=500)

if __name__ == '__main__':
    print("=" * 50)
    print("Proxy Server Starting")
    print(f"Forwarding traffic to: {SERVER_IP}:{SERVER_PORT}")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False)
