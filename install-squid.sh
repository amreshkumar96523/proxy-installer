#!/bin/bash

echo "=== Squid Proxy Auto Installer (IPv4 + IPv6 Support) ==="

read -p "Enter Proxy Username: " PROXY_USER
read -sp "Enter Proxy Password: " PROXY_PASS
echo
read -p "Enter Proxy Port (default 3128): " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-3128}

# Update & install squid + apache-utils for password
apt update -y
apt install -y squid apache2-utils

# Backup original config
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Create password file
htpasswd -b -c /etc/squid/passwd $PROXY_USER $PROXY_PASS

# Detect default interface
DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}')

# Detect IPv4 and IPv6 from default interface
IPV4=$(ip -4 addr show dev $DEFAULT_IFACE | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
IPV6=$(ip -6 addr show dev $DEFAULT_IFACE scope global | grep inet6 | awk '{print $2}' | cut -d'/' -f1 | head -n 1)

# Write new squid config
cat > /etc/squid/squid.conf <<EOF
http_port $PROXY_PORT
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

# Restart Squid
systemctl restart squid
systemctl enable squid

# Output
echo "========================================="
echo "✅ Squid Proxy Installed Successfully!"
echo "IPv4 Proxy: $IPV4:$PROXY_PORT"
echo "IPv6 Proxy: [$IPV6]:$PROXY_PORT"
echo "Username: $PROXY_USER"
echo "Password: $PROXY_PASS"
echo "========================================="
