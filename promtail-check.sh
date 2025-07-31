#!/bin/bash

# === Configuration ===
SCRIPT_PATH="/usr/local/bin/promtail-healthcheck.sh"
SERVICE_PATH="/etc/systemd/system/promtail-healthcheck.service"
TIMER_PATH="/etc/systemd/system/promtail-healthcheck.timer"

cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LAST_BYTES=$(curl -s http://localhost:9080/metrics | grep '^promtail_bytes_sent_total' | awk '{print $2}')
STATE_FILE="/tmp/promtail_last_bytes"

if [ ! -f "$STATE_FILE" ]; then
    echo "$LAST_BYTES" > "$STATE_FILE"
    exit 0
fi

PREV_BYTES=$(cat "$STATE_FILE")
if [ "$LAST_BYTES" == "$PREV_BYTES" ]; then
    echo "Promtail stuck, restarting..."
    systemctl restart promtail.service
else
    echo "Promtail OK"
fi

echo "$LAST_BYTES" > "$STATE_FILE"
EOF

chmod +x "$SCRIPT_PATH"

cat << EOF > "$SERVICE_PATH"
[Unit]
Description=Promtail Health Check
Wants=promtail-healthcheck.timer

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

cat << EOF > "$TIMER_PATH"
[Unit]
Description=Run Promtail Health Check every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=promtail-healthcheck.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now promtail-healthcheck.timer

echo "✅ Health check setup complete."