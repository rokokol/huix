{ ... }:

# gcr's agent instead of OpenSSH's: it keeps key passphrases in the keyring from
# gnome-keyring.nix and asks through its own GTK prompt, so a passphrase is typed once ever
# instead of once per boot. Only one agent may own SSH_AUTH_SOCK, so programs.ssh.startAgent
# stays off — an assertion in the gcr module enforces that
{
  services.gnome.gcr-ssh-agent.enable = true;

  # gcr ships no environment.d snippet and the unit's own Environment= reaches nothing outside
  # the unit, so the socket is exported here — the same hack upstream applies to every session
  # that GNOME does not manage
  environment.extraInit = ''
    if [ -z "$SSH_AUTH_SOCK" ] && [ -n "$XDG_RUNTIME_DIR" ]; then
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
    fi
  '';
}
