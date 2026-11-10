---
title: Опции rokokol.tailnet-web
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.tailnet-web

<!-- generated: option tailnet-web -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.tailnet-web.lan` | — | — | `address=192.168.0.104/24`, `interface=lan` | The LAN link of the host, which sites with `lan` are open to |
| `rokokol.tailnet-web.sites` |  | `comfyui=backend=http://127.0.0.1:8188`, `extraConfig=client_max_body_size 512m;
proxy_read_timeout 900s;
`, `lan=нет`, `port=8189` | `forgejo=backend=http://127.0.0.1:3001`, `extraConfig=client_max_body_size 512m;`, `lan=да`, `port=3000`, `grafana=backend=http://127.0.0.1:3201`, `extraConfig=`, `lan=да`, `port=3200`, `hermes=backend=http://127.0.0.1:9121`, `extraConfig=proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
`, `lan=нет`, `port=9120`, `hindsight=backend=http://127.0.0.1:8888`, `extraConfig=proxy_buffering off;
proxy_read_timeout 900s;
`, `lan=нет`, `port=8788`, `pushgateway=backend=http://127.0.0.1:9191`, `extraConfig=auth_basic "pushgateway";
auth_basic_user_file /run/secrets/pushgateway-htpasswd;
limit_except PUT POST DELETE { deny all; }
set $pushgateway_instance "";
if ($uri ~ "^/metrics/job/[^/]+/instance/([^/]+)$") {
  set $pushgateway_instance $1;
}
if ($pushgateway_instance != $remote_user) {
  return 403;
}
`, `lan=нет`, `port=9091`, `radicale=backend=http://127.0.0.1:5233`, `extraConfig=`, `lan=нет`, `port=5232`, `searxng=backend=http://127.0.0.1:9000`, `extraConfig=`, `lan=нет`, `port=9001` | Sites published to the tailnet, by name |

Объявлено в: `nixos/services/system/tailnet-web.nix`

<!-- /generated -->
