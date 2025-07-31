#!/bin/bash

set -e

# Konfigurasi Loki
LOKI_URL="http://192.168.11.72:3100/loki/api/v1/push"
CONFIG_PATH="/etc/promtail-config.yaml"
SERVICE_PATH="/etc/systemd/system/promtail.service"

# 1. Deteksi OS dan Arsitektur
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Mapping ke format release Grafana
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH_DL="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCH_DL="arm64"
elif [[ "$ARCH" == "armv7l" ]]; then
    ARCH_DL="armv7"
else
    echo "❌ Arsitektur tidak didukung: $ARCH"
    exit 1
fi

echo "🛠 Detected OS: $OS, ARCH: $ARCH → Download: promtail-$OS-$ARCH_DL.zip"

# 2. Install dependensi
apt update && apt install -y curl wget unzip

# 3. Unduh dan pasang promtail
cd /opt
PROMTAIL_URL="https://github.com/grafana/loki/releases/latest/download/promtail-${OS}-${ARCH_DL}.zip"

wget -O promtail.zip "$PROMTAIL_URL"
unzip -o promtail.zip
mv promtail-${OS}-${ARCH_DL} promtail
chmod +x promtail
rm promtail.zip

# 4. Buat konfigurasi promtail
cat <<EOF > $CONFIG_PATH
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: $LOKI_URL

scrape_configs:
  - job_name: journal_portal_service
    journal:
      labels:
        job: portal-service
        host: __HOSTNAME__
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        regex: 'portal.service'
        action: keep
      - source_labels: ['__hostname__']
        target_label: 'instance'
EOF

# 5. Buat systemd service
cat <<EOF > $SERVICE_PATH
[Unit]
Description=Promtail Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/promtail -config.file=$CONFIG_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Enable & Start promtail
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

echo "✅ Promtail berhasil di-install dan logs dikirim ke Loki @ $LOKI_URL"
