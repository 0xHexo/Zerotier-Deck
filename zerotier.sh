#!/bin/bash
# ZeroTier setup

set -Eeuo pipefail

mode="${1:-normal}"
log() { [[ "$mode" != "quiet" ]] && echo "$*"; }
exec_cmd() { 
  if [[ "$mode" == "verbose" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi 
}

# Skip if already running and online
if command -v zerotier-cli >/dev/null 2>&1; then
  if sudo zerotier-cli info 2>/dev/null | grep -q "ONLINE"; then
    log "ZeroTier already active. Exiting."
    exit 0
  fi
fi

# Make system writable 
if ! test -w /usr; then exec_cmd sudo steamos-readonly disable; fi

# Ensure keyrings are present
exec_cmd sudo pacman -Sy --noconfirm
exec_cmd sudo pacman -S --needed --noconfirm archlinux-keyring holo-keyring || true

# Clean previous data
if [[ -d /var/lib/zerotier-one ]]; then
  exec_cmd sudo systemctl stop zerotier-one || true
  exec_cmd sudo rm -rf /var/lib/zerotier-one
fi
exec_cmd sudo install -d -m 700 -o root -g root /var/lib/zerotier-one

# Install or repair
if ! command -v zerotier-cli >/dev/null 2>&1; then
  log "Installing ZeroTier..."
  if sudo pacman -Si zerotier-one >/dev/null 2>&1; then
    exec_cmd sudo pacman -S --overwrite '*' --noconfirm zerotier-one
  else
    exec_cmd bash -c "curl -s https://install.zerotier.com | sudo bash"
  fi
else
  log "ZeroTier detected, checking service..."
fi

# Systemd dependencies
exec_cmd sudo mkdir -p /etc/systemd/system/zerotier-one.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/zerotier-one.service.d/override.conf >/dev/null
[Unit]
Wants=network-online.target
After=network-online.target
EOF
exec_cmd sudo systemctl daemon-reload

# Start service
exec_cmd sudo systemctl enable --now zerotier-one

# Wait for daemon readiness
log "Waiting for zerotier-one..."
for i in {1..30}; do
  [[ -f /var/lib/zerotier-one/zerotier-one.port ]] && break
  sleep 1
done
if [[ ! -f /var/lib/zerotier-one/zerotier-one.port ]]; then
  echo "zerotier-one failed to start. Check logs:" >&2
  sudo journalctl -u zerotier-one -b --no-pager | tail -n 50 >&2
  exit 1
fi

# Ask for network ID
read -rp "ZeroTier Network ID: " NETID
if [[ -n "$NETID" ]]; then
  log "Joining $NETID..."
  for _ in {1..10}; do
    if sudo zerotier-cli join "$NETID" >/dev/null 2>&1; then break; fi
    sleep 3
  done
fi

# Wait for ONLINE state
for _ in {1..20}; do
  sudo zerotier-cli info 2>/dev/null | grep -q "ONLINE" && break
  sleep 3
done

# Simple watchdog
cat <<'EOF' | sudo tee /usr/local/bin/zerotier-watchdog.sh >/dev/null
#!/bin/bash
while true; do
  sleep 300
  if ! zerotier-cli info 2>/dev/null | grep -q ONLINE; then
    systemctl restart zerotier-one
  fi
done
EOF
exec_cmd sudo chmod +x /usr/local/bin/zerotier-watchdog.sh

cat <<'EOF' | sudo tee /etc/systemd/system/zerotier-watchdog.service >/dev/null

[Unit]
Description=ZeroTier Watchdog
After=network-online.target zerotier-one.service

[Service]
ExecStart=/usr/local/bin/zerotier-watchdog.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
exec_cmd sudo systemctl daemon-reload
exec_cmd sudo systemctl enable --now zerotier-watchdog.service

sudo zerotier-cli info || true
log "Setup complete."

#shura