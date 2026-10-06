{ pkgs, pcMac }:
# Fixtures, never real secrets. A throwaway age key is made at build time, and the five names of
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
    } >plain.yaml
    sops --encrypt --age "$(age-keygen -y $out/key.txt)" \
      --input-type yaml --output-type yaml plain.yaml >$out/station.yaml
  ''
