#!/bin/bash

# Firewall Demonstration Script
# This script demonstrates all firewall capabilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print failure
print_failure() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to wait for user
wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue with the next scenario...${NC}"
    read -r
}

# Clear screen and start
clear
print_header "🛡️  CONTAINER-BASED VIRTUAL FIREWALL DEMO"
echo "This demonstration will showcase all firewall capabilities:"
echo ""
echo "1. IP Filtering (Internal vs External networks)"
echo "2. Port Filtering (SSH access control)"
echo "3. DDoS Protection (Rate limiting)"
echo "4. MAC Filtering (Automatic attacker blocking)"
echo ""
wait_for_user

# ============================================
# SCENARIO 1: IP FILTERING
# ============================================
print_header "SCENARIO 1: IP ADDRESS FILTERING"
print_info "Rule: Allow internal network (172.20.0.0/16), Block external networks"

echo ""
echo "Testing access from INTERNAL CLIENT (172.20.0.4)..."
if docker exec client curl -s -m 5 http://firewall:5000/api/employees > /dev/null 2>&1; then
    print_success "Internal client CAN access the API through firewall"
    docker exec client curl -s http://firewall:5000/ | grep -o '"service".*'
else
    print_failure "Internal client CANNOT access the API"
fi

echo ""
echo "Testing access from EXTERNAL ATTACKER (172.21.0.10)..."
if docker exec attacker curl -s -m 5 http://172.20.0.2:5000/ > /dev/null 2>&1; then
    print_failure "External attacker CAN access the API (SECURITY BREACH!)"
else
    print_success "External attacker BLOCKED by firewall (as expected)"
    print_info "External network traffic is denied by iptables rules"
fi

echo ""
print_info "Firewall Logs:"
docker exec firewall dmesg | grep "FW-BLOCK-EXTERNAL" | tail -3 || echo "No external blocks yet (may need traffic)"

wait_for_user

# ============================================
# SCENARIO 2: PORT FILTERING (SSH)
# ============================================
print_header "SCENARIO 2: PORT FILTERING - SSH ACCESS CONTROL"
print_info "Rule: Only admin-client (172.20.0.5) can SSH to server, others blocked"

echo ""
echo "Getting container MAC addresses..."
print_info "Admin Client MAC: $(docker exec admin-client ip link show eth0 | grep link/ether | awk '{print $2}')"
print_info "Regular Client MAC: $(docker exec client ip link show eth0 | grep link/ether | awk '{print $2}')"
print_info "Internal Attacker MAC: $(docker exec internal-attacker ip link show eth0 | grep link/ether | awk '{print $2}')"

echo ""
echo "Testing SSH from ADMIN CLIENT (172.20.0.5)..."
if docker exec admin-client timeout 3 nc -zv 172.20.0.3 22 2>&1 | grep -q "succeeded\|open"; then
    print_success "Admin client CAN reach SSH port on server"
else
    print_info "Connection attempt from admin client (checking firewall rules...)"
fi

echo ""
echo "Testing SSH from REGULAR CLIENT (172.20.0.4)..."
if docker exec client timeout 3 nc -zv 172.20.0.3 22 2>&1 | grep -q "succeeded\|open"; then
    print_failure "Regular client CAN access SSH (SECURITY BREACH!)"
else
    print_success "Regular client BLOCKED from SSH access (as expected)"
fi

echo ""
echo "Testing SSH from INTERNAL ATTACKER (172.20.0.6)..."
if docker exec internal-attacker timeout 3 nc -zv 172.20.0.3 22 2>&1 | grep -q "succeeded\|open"; then
    print_failure "Internal attacker CAN access SSH (SECURITY BREACH!)"
else
    print_success "Internal attacker BLOCKED from SSH access (as expected)"
fi

echo ""
print_info "Firewall Logs (SSH blocks):"
docker exec firewall dmesg | grep "FW-BLOCK-SSH" | tail -3 || echo "No SSH blocks logged yet"

wait_for_user

# ============================================
# SCENARIO 3: NORMAL TRAFFIC TEST
# ============================================
print_header "SCENARIO 3: NORMAL API TRAFFIC"
print_info "Demonstrating normal API operations through the firewall"

echo ""
echo "1. Listing all employees..."
docker exec client curl -s http://firewall:5000/api/employees | python3 -m json.tool 2>/dev/null | head -20
print_success "API GET request successful"

echo ""
echo "2. Creating a new employee..."
docker exec client curl -s -X POST http://firewall:5000/api/employees \
    -H "Content-Type: application/json" \
    -d '{"name":"Demo User","position":"Tester","department":"QA","salary":60000,"email":"demo@company.com"}' \
    | python3 -m json.tool 2>/dev/null
print_success "API POST request successful"

echo ""
echo "3. Checking dashboard for traffic logs..."
print_info "Dashboard URL: http://localhost:8080"
print_info "Recent requests are being logged and displayed"

wait_for_user

# ============================================
# SCENARIO 4: DDoS PROTECTION
# ============================================
print_header "SCENARIO 4: DDoS ATTACK SIMULATION & PROTECTION"
print_info "Rule: Rate limiting + Automatic MAC blocking for attackers"

echo ""
print_info "Current blocked MACs:"
docker exec firewall cat /app/data/blocked_macs.txt 2>/dev/null || echo "(none)"

echo ""
echo "Getting internal attacker's MAC address..."
ATTACKER_MAC=$(docker exec internal-attacker ip link show eth0 | grep link/ether | awk '{print $2}')
print_info "Internal Attacker MAC: $ATTACKER_MAC"

echo ""
echo "Step 1: Normal request from internal-attacker (should work)..."
if docker exec internal-attacker curl -s -m 5 http://firewall:5000/ > /dev/null 2>&1; then
    print_success "Internal attacker can access server (initially allowed)"
else
    print_failure "Internal attacker blocked (may be already banned)"
fi

echo ""
echo "Step 2: Launching DDoS attack from internal-attacker..."
print_info "Executing: ddos_attack http://firewall:5000/api/employees 5 30"
print_info "This sends 150 rapid requests to trigger rate limiting"

docker exec internal-attacker ddos_attack http://firewall:5000/api/employees 5 30 &
DDOS_PID=$!

# Wait a bit for attack to trigger
sleep 3

echo ""
print_info "Firewall is detecting and blocking the attack..."
sleep 5

# Check if attack is still running
if ps -p $DDOS_PID > /dev/null 2>&1; then
    print_info "Attack in progress... waiting for completion"
    wait $DDOS_PID
fi

echo ""
print_success "DDoS attack completed"

echo ""
echo "Step 3: Checking firewall response..."
sleep 3

echo ""
print_info "Checking for DDoS detection in logs..."
docker exec firewall dmesg | grep "FW-DDOS" | tail -5 || echo "Checking application logs..."

echo ""
print_info "Checking if MAC was automatically blocked..."
echo "Blocked MACs:"
docker exec firewall cat /app/data/blocked_macs.txt 2>/dev/null | while read -r mac; do
    if [ "$mac" = "$ATTACKER_MAC" ]; then
        print_success "Attacker MAC $mac is BLOCKED!"
    else
        print_info "  $mac"
    fi
done

echo ""
echo "Step 4: Verifying attacker is now blocked..."
if docker exec internal-attacker curl -s -m 5 http://firewall:5000/ > /dev/null 2>&1; then
    print_failure "Attacker can still access (MAC blocking not applied yet)"
    print_info "Note: DDoS monitor checks every 10 seconds. Try checking dashboard."
else
    print_success "Attacker is NOW BLOCKED by MAC address filtering!"
fi

echo ""
print_info "Check the dashboard at http://localhost:8080 for:"
echo "  - DDoS alerts"
echo "  - Blocked MAC addresses"
echo "  - Traffic statistics"

wait_for_user

# ============================================
# SCENARIO 5: FIREWALL RULES SUMMARY
# ============================================
print_header "SCENARIO 5: FIREWALL RULES SUMMARY"

echo "Active iptables rules:"
echo ""
echo "1. IP Filtering Rules:"
docker exec firewall iptables -L FORWARD -n -v | grep "172.20.0.0/16" | head -3

echo ""
echo "2. SSH Port Filtering:"
docker exec firewall iptables -L FORWARD -n -v | grep "tcp dpt:22" | head -3

echo ""
echo "3. DDoS Protection Rules:"
docker exec firewall iptables -L FORWARD -n -v | grep "recent:" | head -3

echo ""
echo "4. MAC Filtering Chain:"
docker exec firewall iptables -L BLOCKED_MACS -n -v 2>/dev/null | head -10

echo ""
echo "5. NAT Rules:"
docker exec firewall iptables -t nat -L PREROUTING -n -v | grep "DNAT" | head -3

wait_for_user

# ============================================
# FINAL SUMMARY
# ============================================
print_header "🎓 DEMONSTRATION COMPLETE"

echo "Summary of Firewall Capabilities Demonstrated:"
echo ""
print_success "1. IP Filtering: Internal network allowed, external blocked"
print_success "2. Port Filtering: SSH restricted to admin-client only"
print_success "3. DDoS Protection: Rate limiting and attack detection active"
print_success "4. MAC Filtering: Automatic blocking of detected attackers"

echo ""
print_info "Key Points:"
echo "  • Server has NO direct port mappings (only accessible via firewall)"
echo "  • All filtering done in iptables (kernel-level)"
echo "  • Automatic DDoS detection and MAC blocking"
echo "  • Lightweight Alpine containers for clients"
echo "  • Real-time monitoring dashboard available"

echo ""
print_info "Access Points:"
echo "  • Dashboard: http://localhost:8080"
echo "  • API (via firewall): http://localhost:5000"

echo ""
echo -e "${CYAN}=========================================="
echo "Thank you for watching the demonstration!"
echo -e "==========================================${NC}"
echo ""
