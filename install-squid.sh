#!/bin/bash

API_URL="https://joy.services/ip-api/"

echo "=== Squid Proxy Auto Installer (IPv4 + Auto IPv6 from API - No jq) ==="

# Get IPv6 details from API
RESPONSE=$(curl -s "$API_URL")

# Extract values using grep/sed
IPV6=$(echo "$RESPONSE" | grep -oP '"ipv6":"\K[^"]+')
GATEWAY_V6=$(echo "$RESPONSE" | grep -oP '"gateway":"\K[^"]+')
PREFIX_LEN=48  # Always 48

# Validate
if [[ -z "$IPV6" || -z "$GATEWAY_V6" ]]; then
    echo "❌ Failed to fetch IPv6 details from API"
    exit 1
fi

echo "Using IPv6: $IPV6/$PREFIX_LEN"
echo "Gateway: $GATEWAY_V6"

# Get proxy login details
read -p "Enter Proxy Username: " PROXY_USER
read -sp "Enter Proxy Password: " PROXY_PASS
echo
read -p "Enter Proxy Port (default 3128): " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-3128}

# Install squid and dependencies
apt update -y
apt install -y squid apache2-utils

# Backup squid config
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Create passwd file
htpasswd -b -c /etc/squid/passwd $PROXY_USER $PROXY_PASS

# Detect default interface & IPv4
DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}')
IPV4=$(ip -4 addr show dev $DEFAULT_IFACE | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -n 1)

# Add IPv6 if not already present
if ! ip -6 addr show dev $DEFAULT_IFACE | grep -q "$IPV6"; then
    ip -6 addr add $IPV6/$PREFIX_LEN dev $DEFAULT_IFACE
    ip -6 route add default via $GATEWAY_V6 dev $DEFAULT_IFACE
fi

# Configure squid
cat > /etc/squid/squid.conf <<EOF
http_port $PROXY_PORT
http_port [${IPV6}]:$PROXY_PORT
acl allowed_ips src 0.0.0.0/0
acl allowed_ips6 src ::/0
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access allow allowed_ips
http_access allow allowed_ips6
http_access deny all
via off
forwarded_for delete
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
EOF

# Restart squid
systemctl restart squid
systemctl enable squid

echo "========================================="
echo "✅ Squid Proxy Installed Successfully!"
echo "IPv4 Proxy: $IPV4:$PROXY_PORT"
echo "IPv6 Proxy: [$IPV6]:$PROXY_PORT"
echo "Username: $PROXY_USER"
echo "Password: $PROXY_PASS"
echo "========================================="
