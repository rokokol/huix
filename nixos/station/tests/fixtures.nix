{
  pkgs,
  pcMac,
  # Only the boot test reaches a GitHub
  githubToken ? "unused",
  # The Telegram chat the agent's bot answers
  telegramOwner ? "1",
}:
# Fixtures, never real secrets. Each secret file uses a throwaway age key made at build time
pkgs.runCommand "station-boot-test-fixtures"
  {
    nativeBuildInputs = with pkgs; [
      age
      mkpasswd
      sops
      syncthing
    ];
  }
  ''
    mkdir $out
    age-keygen -o $out/key.txt 2>/dev/null
    # The station's Syncthing key, and the device ID it must come up with
    HOME=$PWD syncthing generate --home=syncthing >/dev/null 2>&1
    HOME=$PWD syncthing device-id --home=syncthing >$out/syncthing-device-id
    {
      printf 'rokokol-password-hash: %s\n' "$(mkpasswd -m sha-512 test)"
      printf 'pc-mac: %s\n' '${pcMac}'
      # Marked $2y$, as htpasswd -B writes it and the real file holds it; mkpasswd writes $2b$
      printf 'restic-server-htpasswd: |\n  pc:%s\n  station:%s\n' \
        "$(mkpasswd -m bcrypt test | sed 's/^\$2b\$/$2y$/')" \
        "$(mkpasswd -m bcrypt test | sed 's/^\$2b\$/$2y$/')"
      printf 'radicale-password-rokokol: %s\n' test
      printf 'radicale-password-mya: %s\n' test
      printf 'alert-mail-msmtprc: |\n'
      printf '  account default\n  host 192.168.0.1\n  port 1025\n'
      printf '  from station@test\n  auth off\n  tls off\n'
      printf 'alert-mail-aliases: "root: owner@test"\n'
      printf 'github-mirror-token: %s\n' '${githubToken}'
      printf 'forgejo-runner-nixos-pc: %s\n' 0123456789abcdef01234567
      printf 'grafana-admin-password: %s\n' test
      printf 'grafana-secret-key: %s\n' 0123456789abcdef0123456789abcdef
      printf 'telegram-bot-token: %s\n' 123456789:test-token
      printf 'openrouter-api-key: test\n'
      printf 'hermes-webhook-secret: test-webhook-secret\n'
      printf 'hermes-dashboard-password: test-dashboard-password\n'
      printf 'hermes-dashboard-secret: test-dashboard-secret-long-enough-0123456789\n'
      printf 'hermes-restic-password: test\n'
      printf 'hermes-restic-rest-password: test\n'
      printf 'semantic-scholar-api-key: test\n'
      printf 'core-api-key: test\n'
      printf 'unpaywall-email: test@example.org\n'
      printf 'github-token: %s\n' github_pat_test
      printf 'github-token-classic: %s\n' ghp_test
      printf 'telegram-owner-chat-id: "%s"\n' '${telegramOwner}'
      for part in key cert; do
        printf 'syncthing-%s-nixos-station: |\n' "$part"
        sed 's/^/  /' "syncthing/$part.pem"
      done
    } >station.yaml
    # No mailbox connects to a real server from a test VM
    printf 'config: "{}"\n' >mail-agent.yaml
    printf 'telegram-api-id: "12345"\ntelegram-api-hash: test\n' >telegram-agent.yaml
    for name in station mail-agent telegram-agent; do
      sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
        --input-type yaml --output-type yaml "$name.yaml" >"$out/$name.yaml"
    done
  ''
