#!/bin/bash

# ========= SYSTEM REQUIREMENTS =========
echo "[*] Updating system..."
sudo apt update && sudo apt upgrade -y

# ========= INSTALL LOKI =========
echo "[*] Installing Loki..."
cd /opt
wget https://github.com/grafana/loki/releases/latest/download/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
mv loki-linux-amd64 loki
chmod +x loki
sudo mv loki-linux-amd64 /usr/local/bin/loki

cat <<EOF | sudo tee /etc/loki-config.yaml
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
EOF

# ====== SYSTEMD FOR LOKI ======
cat <<EOF | sudo tee /etc/systemd/system/loki.service
[Unit]
Description=Loki Log Aggregation
After=network.target

[Service]
Type=simple
ExecStart=/opt/loki -config.file=/opt/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now loki
sudo systemctl status loki
curl http://localhost:3100/ready

# ========= INSTALL GRAFANA =========
# echo "[*] Installing Grafana..."
# sudo apt install -y apt-transport-https software-properties-common wget
# wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
# echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# sudo apt update
# sudo apt install grafana -y
# sudo systemctl enable --now grafana-server

# echo "[*] Loki + Grafana installation completed!"
