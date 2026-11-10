---
title: Модули nixos/services/system/grafana
kind: module
---

# Модули nixos/services/system/grafana

<!-- generated: module nixos/services/system/grafana -->

## `nixos/services/system/grafana/alerting.nix`

The resource rules of resources.nix as Grafana's own alerting, and their way out: a webhook to
the bridge beside this file, which writes the causes file that the host's alert registry reads.
So a firing rule arrives by the same mail, Telegram message and morning digest as a failed unit,
with one place that holds the relay and the bot, and the registry closes a problem when Grafana
sends its resolution. The bridge accepts only the alerts labelled huix_resource, so a rule added
by hand in the UI cannot mail through the registry

**Юниты:** `grafana-alerts`

## `nixos/services/system/grafana/grafana.nix`

Grafana over the Prometheus of this host, through its tailnet-web site, which the LAN reaches
too. Whoever reaches the site sees the dashboards without a login, as a viewer; the admin signs
in from either network. Grafana binds to loopback.

Grafana sets the admin password from sops only when it makes its database. To change it later,
run `grafana cli admin reset-admin-password` as the grafana user, then change the secret

**Опции:** `rokokol.grafana.dashboardTitles`, `rokokol.grafana.enable`, `rokokol.grafana.resourcePolicy`

Подробнее: [опции rokokol.grafana](../options/grafana.md)

## `nixos/services/system/grafana/panels.nix`

The pieces every dashboard here is built of, as Grafana's JSON model. Every colour is a role of
ddlc-themes. Grafana keeps one colour per series whatever its theme, so the colours are the dark
roles and the UI is dark too. No series takes series-2: it is the red of danger, and a plain
line in it reads as an alarm

## `nixos/services/system/grafana/resources.nix`

The thresholds, the queries and the rules of the resource alerts, in one place: a panel turns
red at the value a rule alerts at, and a check proves each rule fires where it should. The
station is the host of this Grafana, so its own metrics need no push and no freshness guard;
the nodes behind the Pushgateway report their disk themselves at their own ratio, so Grafana
adds only the forecast there, and guards it against a group that stopped being pushed

<!-- /generated -->
