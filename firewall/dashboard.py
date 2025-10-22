"""
Firewall Dashboard - Web interface for monitoring and managing firewall
"""
from flask import Flask, render_template_string, request, jsonify
from flask_cors import CORS
from datetime import datetime, timedelta
import json
from collections import deque
from threading import Lock

app = Flask(__name__)
CORS(app)

# In-memory data structures
request_log = deque(maxlen=10000)  # Store last 10000 requests
blocked_macs = set()  # Set of blocked MAC addresses
data_lock = Lock()  # Thread safety for concurrent access

def log_request(client_ip, method, path, status, blocked=False, reason=None):
    """Log a request to in-memory storage"""
    with data_lock:
        entry = {
            'timestamp': datetime.now().isoformat(),
            'client_ip': client_ip,
            'method': method,
            'path': path,
            'status': status,
            'blocked': blocked
        }
        if reason:
            entry['reason'] = reason
        request_log.append(entry)

def add_blocked_mac(mac_address):
    """Add a MAC address to the blocked list"""
    with data_lock:
        blocked_macs.add(mac_address)

def get_recent_requests(minutes=10):
    """Get recent requests from in-memory log"""
    cutoff_time = datetime.now() - timedelta(minutes=minutes)
    requests = []
    
    with data_lock:
        for req in request_log:
            try:
                req_time = datetime.fromisoformat(req['timestamp'])
                if req_time >= cutoff_time:
                    requests.append(req)
            except:
                continue
    
    return sorted(requests, key=lambda x: x['timestamp'], reverse=True)

def get_blocked_macs():
    """Get list of blocked MAC addresses"""
    with data_lock:
        return list(blocked_macs)

def get_statistics():
    """Get firewall statistics"""
    requests = get_recent_requests(60)  # Last hour
    
    total_requests = len(requests)
    internal_requests = sum(1 for r in requests if r.get('client_ip', '').startswith('172.20.'))
    external_requests = total_requests - internal_requests
    blocked_requests = sum(1 for r in requests if r.get('blocked', False) or r.get('status', 200) >= 400)
    
    # Detect potential DDoS - check last minute
    ip_counts = {}
    recent_requests = get_recent_requests(1)  # Last minute
    for req in recent_requests:
        ip = req.get('client_ip', 'unknown')
        ip_counts[ip] = ip_counts.get(ip, 0) + 1
    
    # DDoS threshold: more than 20 requests per minute from single IP
    ddos_alerts = [
        {
            'ip': ip, 
            'count': count,
            'network': 'Internal (172.20.x.x)' if ip.startswith('172.20.') else 'External',
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'status': 'BLOCKING' if count > 20 else 'MONITORING'
        } 
        for ip, count in ip_counts.items() if count > 15  # Show warning earlier
    ]
    
    # Get blocked request attempts (MAC blocked requests)
    blocked_attempts = [r for r in get_recent_requests(10) if r.get('blocked', False) and r.get('status') == 403]
    
    # Top IPs by request count
    all_ips = {}
    for req in requests:
        ip = req.get('client_ip', 'unknown')
        all_ips[ip] = all_ips.get(ip, 0) + 1
    
    top_ips = sorted(all_ips.items(), key=lambda x: x[1], reverse=True)[:10]
    
    return {
        'total_requests': total_requests,
        'internal_requests': internal_requests,
        'external_requests': external_requests,
        'blocked_requests': blocked_requests,
        'allowed_requests': total_requests - blocked_requests,
        'ddos_alerts': ddos_alerts,
        'blocked_attempts': len(blocked_attempts),
        'top_ips': top_ips
    }

def get_network_type(ip):
    """Determine if IP is from internal or external network"""
    if ip.startswith('172.20.'):
        return 'Internal'
    elif ip.startswith('172.21.'):
        return 'External'
    else:
        return 'Unknown'

DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Firewall Traffic Monitor</title>
    <meta http-equiv="refresh" content="5">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #2c3e50;
            display: flex;
            align-items: center;
            gap: 15px;
            font-size: 32px;
        }
        .header .status {
            background: #2ecc71;
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: normal;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        .header .subtitle {
            color: #7f8c8d;
            margin-top: 10px;
            font-size: 14px;
        }
        .policy-banner {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            padding: 20px 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .policy-banner h2 {
            font-size: 18px;
            margin-bottom: 10px;
        }
        .policy-banner p {
            font-size: 14px;
            opacity: 0.9;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
        }
        .stat-card h3 {
            color: #7f8c8d;
            font-size: 12px;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .stat-card .value {
            font-size: 36px;
            font-weight: bold;
            color: #2c3e50;
        }
        .stat-card .subtext {
            color: #95a5a6;
            font-size: 12px;
            margin-top: 5px;
        }
        .stat-card.total .value { color: #3498db; }
        .stat-card.internal .value { color: #2ecc71; }
        .stat-card.external .value { color: #e74c3c; }
        .stat-card.blocked .value { color: #e67e22; }
        
        .alert {
            background: #fff3cd;
            border-left: 4px solid #f39c12;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            animation: shake 0.5s;
        }
        .alert.danger {
            background: #f8d7da;
            border-left-color: #e74c3c;
        }
        .alert h3 {
            color: #721c24;
            margin-bottom: 10px;
            font-size: 18px;
        }
        .alert-item {
            background: white;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-10px); }
            75% { transform: translateX(10px); }
        }
        
        .content-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .card h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #ecf0f1;
            font-size: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid #ecf0f1;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #2c3e50;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .badge {
            padding: 5px 10px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .badge.success { background: #d4edda; color: #155724; }
        .badge.danger { background: #f8d7da; color: #721c24; }
        .badge.warning { background: #fff3cd; color: #856404; }
        .badge.internal { background: #d1ecf1; color: #0c5460; }
        .badge.external { background: #f8d7da; color: #721c24; }
        
        .scroll-container {
            max-height: 500px;
            overflow-y: auto;
        }
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #95a5a6;
        }
        .empty-state-icon {
            font-size: 48px;
            margin-bottom: 15px;
        }
        code {
            background: #ecf0f1;
            padding: 4px 8px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>
                🛡️ Firewall Traffic Monitor
                <span class="status">● ACTIVE</span>
            </h1>
            <p class="subtitle">Network-based access control • Auto-refresh: 5s • Last updated: {{ now }}</p>
        </div>

        <div class="policy-banner">
            <h2>🔒 Network Access Policy</h2>
            <p>✅ <strong>Internal Network (172.20.0.0/16):</strong> All traffic ALLOWED</p>
            <p>❌ <strong>External Networks:</strong> All traffic BLOCKED by default</p>
        </div>

        {% if stats.ddos_alerts %}
        <div class="alert danger">
            <h3>⚠️ DDoS ATTACK DETECTED - AUTO-BLOCKING IN PROGRESS!</h3>
            <p style="margin-bottom: 15px;">High traffic detected - MAC addresses being blocked automatically:</p>
            {% for alert in stats.ddos_alerts %}
                <div class="alert-item">
                    <div>
                        <strong>IP:</strong> <code>{{ alert.ip }}</code>
                        <span class="badge {{ 'internal' if alert.network == 'Internal (172.20.x.x)' else 'external' }}">{{ alert.network }}</span>
                        <span class="badge {{ 'danger' if alert.status == 'BLOCKING' else 'warning' }}">{{ alert.status }}</span>
                    </div>
                    <div>
                        <strong style="color: #e74c3c; font-size: 18px;">{{ alert.count }} requests/min</strong>
                    </div>
                </div>
            {% endfor %}
            <p style="margin-top: 15px; font-size: 12px; opacity: 0.8;">
                ℹ️ Monitor checks every 2 seconds and blocks MAC addresses exceeding 20 req/min threshold
            </p>
        </div>
        {% endif %}

        <div class="stats-grid">
            <div class="stat-card total">
                <h3>Total Requests</h3>
                <div class="value">{{ stats.total_requests }}</div>
                <div class="subtext">Last hour</div>
            </div>
            <div class="stat-card internal">
                <h3>Internal Traffic</h3>
                <div class="value">{{ stats.internal_requests }}</div>
                <div class="subtext">From 172.20.x.x</div>
            </div>
            <div class="stat-card external">
                <h3>External Traffic</h3>
                <div class="value">{{ stats.external_requests }}</div>
                <div class="subtext">From other networks</div>
            </div>
            <div class="stat-card blocked">
                <h3>Blocked Attempts</h3>
                <div class="value">{{ stats.blocked_attempts }}</div>
                <div class="subtext">MAC blocked (last 10 min)</div>
            </div>
        </div>

        <div class="content-grid">
            <div class="card">
                <h2>📊 Top Traffic Sources (Last Hour)</h2>
                <div class="scroll-container">
                    <table>
                        <thead>
                            <tr>
                                <th>IP Address</th>
                                <th>Network</th>
                                <th>Total Requests</th>
                                <th>Percentage</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% if stats.top_ips %}
                                {% for ip, count in stats.top_ips %}
                                <tr>
                                    <td><code>{{ ip }}</code></td>
                                    <td>
                                        {% if ip.startswith('172.20.') %}
                                            <span class="badge internal">Internal</span>
                                        {% elif ip.startswith('172.21.') %}
                                            <span class="badge external">External</span>
                                        {% else %}
                                            <span class="badge warning">Unknown</span>
                                        {% endif %}
                                    </td>
                                    <td><strong>{{ count }}</strong></td>
                                    <td>{{ "%.1f"|format((count / stats.total_requests * 100) if stats.total_requests > 0 else 0) }}%</td>
                                </tr>
                                {% endfor %}
                            {% else %}
                                <tr><td colspan="4" class="empty-state">
                                    <div class="empty-state-icon">📭</div>
                                    <div>No traffic recorded yet</div>
                                </td></tr>
                            {% endif %}
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="card">
                <h2>📝 Recent Traffic Log</h2>
                <div class="scroll-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>Client IP</th>
                                <th>Network</th>
                                <th>Method</th>
                                <th>Path</th>
                                <th>Status</th>
                                <th>Details</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% if recent_requests %}
                                {% for req in recent_requests[:100] %}
                                <tr>
                                    <td style="font-size: 12px;">{{ req.timestamp[11:19] }}</td>
                                    <td><code>{{ req.client_ip }}</code></td>
                                    <td>
                                        {% if req.client_ip.startswith('172.20.') %}
                                            <span class="badge internal">Int</span>
                                        {% elif req.client_ip.startswith('172.21.') %}
                                            <span class="badge external">Ext</span>
                                        {% else %}
                                            <span class="badge warning">Unk</span>
                                        {% endif %}
                                    </td>
                                    <td><strong>{{ req.method }}</strong></td>
                                    <td style="max-width: 300px; overflow: hidden; text-overflow: ellipsis;">{{ req.path }}</td>
                                    <td>
                                        {% if req.status < 400 %}
                                            <span class="badge success">{{ req.status }}</span>
                                        {% else %}
                                            <span class="badge danger">{{ req.status }}</span>
                                        {% endif %}
                                    </td>
                                    <td style="font-size: 12px; color: #95a5a6;">
                                        {% if req.get('reason') %}
                                            🚫 {{ req.reason }}
                                        {% elif req.blocked %}
                                            🚫 Blocked
                                        {% else %}
                                            ✓ Allowed
                                        {% endif %}
                                    </td>
                                </tr>
                                {% endfor %}
                            {% else %}
                                <tr><td colspan="7" class="empty-state">
                                    <div class="empty-state-icon">📭</div>
                                    <div>No traffic logged yet</div>
                                </td></tr>
                            {% endif %}
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="card">
                <h2>🚫 Blocked MAC Addresses (Auto-blocked by DDoS Detection)</h2>
                <div class="scroll-container">
                    <table>
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>MAC Address</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% if blocked_macs %}
                                {% for mac in blocked_macs %}
                                <tr>
                                    <td>{{ loop.index }}</td>
                                    <td><code>{{ mac }}</code></td>
                                    <td><span class="badge danger">BLOCKED</span></td>
                                </tr>
                                {% endfor %}
                            {% else %}
                                <tr><td colspan="3" class="empty-state">
                                    <div class="empty-state-icon">✅</div>
                                    <div>No MAC addresses blocked yet</div>
                                </td></tr>
                            {% endif %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def dashboard():
    """Main dashboard page - Traffic monitoring and firewall status"""
    stats = get_statistics()
    recent_requests = get_recent_requests(10)
    blocked_macs = get_blocked_macs()
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    return render_template_string(
        DASHBOARD_HTML,
        stats=stats,
        recent_requests=recent_requests,
        blocked_macs=blocked_macs,
        now=now
    )

@app.route('/api/stats')
def api_stats():
    """API endpoint for statistics"""
    return jsonify(get_statistics())

@app.route('/api/logs')
def api_logs():
    """API endpoint for recent logs"""
    minutes = request.args.get('minutes', 10, type=int)
    return jsonify(get_recent_requests(minutes))

@app.route('/api/log', methods=['POST'])
def api_log():
    """API endpoint to receive log entries from proxy"""
    try:
        data = request.get_json()
        log_request(
            data['client_ip'],
            data['method'],
            data['path'],
            data['status'],
            data.get('blocked', False),
            data.get('reason')
        )
        return jsonify({'status': 'ok'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/blocked_macs')
def api_blocked_macs():
    """API endpoint to get blocked MAC addresses"""
    return jsonify({'blocked_macs': get_blocked_macs()})

@app.route('/api/block_mac', methods=['POST'])
def api_block_mac():
    """API endpoint to block a MAC address"""
    try:
        data = request.get_json()
        mac = data.get('mac')
        if mac:
            add_blocked_mac(mac)
            return jsonify({'status': 'ok', 'mac': mac}), 200
        return jsonify({'error': 'MAC address required'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 400

if __name__ == '__main__':
    print("=" * 50)
    print("Firewall Dashboard Starting")
    print("Access at: http://localhost:8080")
    print("=" * 50)
    app.run(host='0.0.0.0', port=8080, debug=False)
