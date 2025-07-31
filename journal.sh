server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions-journal.yaml

clients:
  - url: http://192.168.11.72:3100/loki/api/v1/push

scrape_configs:
  - job_name: systemd-journal
    journal:
      max_age: 12h
      labels:
        job: portal
        __path__: /var/log/journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        regex: 'portal\.service'
        action: keep
      - source_labels: ['__hostname__']
        target_label: instance
      - replacement: '192.168.2.6'  # <-- GANTI DI 192.168.2.8 NANTI
        target_label: ip
