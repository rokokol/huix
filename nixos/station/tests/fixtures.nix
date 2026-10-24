{
  pkgs,
  pcMac,
  # Only the boot test reaches a GitHub
  githubToken ? "unused",
  # The Telegram chat the agent's bot answers
  telegramOwner ? "1",
}:
# Fixtures, never real secrets. A throwaway age key is made at build time, and the names of
# secrets/station.yaml get dummy values, encrypted to that key only
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
      printf 'restic-server-htpasswd: pc:%s\n' "$(mkpasswd -m bcrypt test | sed 's/^\$2b\$/$2y$/')"
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
      printf 'github-token: %s\n' github_pat_test
      printf 'github-token-classic: %s\n' ghp_test
      printf 'telegram-owner-chat-id: "%s"\n' '${telegramOwner}'
      for part in key cert; do
        printf 'syncthing-%s-nixos-station: |\n' "$part"
        sed 's/^/  /' "syncthing/$part.pem"
      done
    } >plain.yaml
    sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
      --input-type yaml --output-type yaml plain.yaml >$out/station.yaml
    # No mailbox connects to a real server from a test VM
    printf 'config: "{}"\n' >mail-agent.yaml
    sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
      --input-type yaml --output-type yaml mail-agent.yaml >$out/mail-agent.yaml
  ''
