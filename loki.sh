#!/bin/bash

# ========= SYSTEM REQUIREMENTS =========
echo "[*] Updating system..."
sudo apt update && sudo apt upgrade -y

# ========= INSTALL LOKI =========
echo "[*] Installing Loki..."
wget -qO loki-linux-amd64.zip https://github.com/grafana/loki/releases/latest/download/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
chmod +x loki-linux-amd64
sudo mv loki-linux-amd64 /usr/local/bin/loki

cat <<EOF | sudo tee /etc/loki-config.yaml
auth_enabled: false
server:
  http_listen_port: 3100
  grpc_listen_port: 9095
ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  max_transfer_retries: 0
schema_config:
  configs:
  - from: 2025-07-30
    store: boltdb-shipper
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/index
    cache_location: /tmp/loki/boltdb-cache
    shared_store: filesystem
  filesystem:
    directory: /tmp/loki/chunks
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
chunk_store_config:
  max_look_back_period: 0s
table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
EOF

# ====== SYSTEMD FOR LOKI ======
cat <<EOF | sudo tee /etc/systemd/system/loki.service
[Unit]
Description=Loki Log Aggregator
After=network.target

[Service]
ExecStart=/usr/local/bin/loki -config.file=/etc/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now loki

# ========= INSTALL GRAFANA =========
# echo "[*] Installing Grafana..."
# sudo apt install -y apt-transport-https software-properties-common wget
# wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
# echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# sudo apt update
# sudo apt install grafana -y
# sudo systemctl enable --now grafana-server

# echo "[*] Loki + Grafana installation completed!"
