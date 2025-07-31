# Loki + Promtail + Grafana Monitoring Setup

This guide explains how to set up **Grafana Loki** (without Docker) along with **Promtail** to monitor logs from remote servers (e.g., gate sensors) and display them in **Grafana**.

---

## 🔧 1. Install Loki Binary on Grafana Server

```bash
cd /opt
wget https://github.com/grafana/loki/releases/latest/download/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
mv loki-linux-amd64 loki
chmod +x loki
```

## ⚙️ 2. Create Loki Configuration

File: `/opt/loki-config.yaml`

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  log_level: info

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  max_chunk_age: 1h

schema_config:
  configs:
    - from: 2022-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v12
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/index
    cache_location: /tmp/loki/cache
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  allow_structured_metadata: false

table_manager:
  retention_deletes_enabled: true
  retention_period: 120h
```

## 🧩 3. Create Loki Systemd Service

File: `/etc/systemd/system/loki.service`

```ini
[Unit]
Description=Loki Log Aggregation
After=network.target

[Service]
Type=simple
ExecStart=/opt/loki -config.file=/opt/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start Loki:

```bash
sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki
sudo systemctl status loki
curl http://localhost:3100/ready
```

Expected output: `Ready`

---

## 📊 4. Add Loki to Grafana

1. Access Grafana Web (e.g., http://localhost:3000)
2. Navigate: **Connections → Data Sources**
3. Click **Add data source**
4. Choose **Loki**
5. Set URL: `http://localhost:3100`
6. Click **Save & Test**

---

## 🌐 5. Configure Promtail on Remote Servers

Create file `/etc/promtail-config.yaml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.11.72:3100/loki/api/v1/push

scrape_configs:
  - job_name: journal_portal_masukmotor_service
    journal:
      labels:
        job: masukmotor-portal-service
        host: __HOSTNAME__
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        regex: 'portal.service'
        action: keep
      - source_labels: ['__hostname__']
        target_label: 'instance'
```

---

## 🤖 6. Health Check Script

Create file: `promtail-check.sh`

```bash
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
```

Run the script:

```bash
chmod +x promtail-check.sh
sudo ./promtail-check.sh
```

Check services:

```bash
sudo systemctl status promtail
journalctl -u promtail -b --no-pager
curl http://192.168.11.72:3100/ready
```

Ensure firewall allows Loki port:

```bash
sudo ufw allow 3100/tcp
# or
sudo iptables -A INPUT -p tcp --dport 3100 -j ACCEPT
```

---

## 🔍 7. Explore Logs in Grafana

Use Explore panel with query:

```logql
{job="portal-service"}
```

Or filter by instance:

```logql
{job="portal-service", instance="masukmotor-portal-service"}
```

---

## ✅ DONE! Now your logs are visible in Grafana from remote hosts.