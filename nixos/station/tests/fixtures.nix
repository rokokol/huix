{
  pkgs,
  pcMac,
  # Only the boot test reaches a GitHub
  githubToken ? "unused",
}:
# Fixtures, never real secrets. A throwaway age key is made at build time, and the names of
# secrets/station.yaml get dummy values, encrypted to that key only
pkgs.runCommand "station-boot-test-fixtures"
  {
    nativeBuildInputs = with pkgs; [
      age
      mkpasswd
      sops
    ];
  }
  ''
    mkdir $out
    age-keygen -o $out/key.txt 2>/dev/null
    {
      printf 'rokokol-password-hash: %s\n' "$(mkpasswd -m sha-512 test)"
      printf 'pc-mac: %s\n' '${pcMac}'
      printf 'restic-server-htpasswd: pc:%s\n' "$(mkpasswd -m bcrypt test)"
      printf 'alert-mail-msmtprc: |\n'
      printf '  account default\n  host 192.168.0.1\n  port 1025\n'
      printf '  from station@test\n  auth off\n  tls off\n'
      printf 'alert-mail-aliases: "root: owner@test"\n'
      printf 'github-mirror-token: %s\n' '${githubToken}'
      printf 'forgejo-runner-nixos-pc: %s\n' 0123456789abcdef01234567
      printf 'grafana-admin-password: %s\n' test
      printf 'grafana-secret-key: %s\n' 0123456789abcdef0123456789abcdef
    } >plain.yaml
    sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
      --input-type yaml --output-type yaml plain.yaml >$out/station.yaml
  ''
