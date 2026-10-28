{ pkgs, fixtures }:

let
  inherit (pkgs) lib;
  secrets =
    pkgs.runCommand "sops-activation-fixtures"
      {
        nativeBuildInputs = with pkgs; [
          age
          sops
        ];
      }
      ''
        mkdir "$out"
        for value in original rotated; do
          printf 'activation-probe: %s\n' "$value" >"$value.yaml"
          sops --encrypt --age "$(age-keygen -y ${fixtures}/key.txt)" \
            --input-type yaml --output-type yaml "$value.yaml" >"$out/$value.yaml"
        done
      '';
in
{
  nodes.station =
    { config, ... }:
    {
      sops.secrets.activation-probe = {
        sopsFile = "${secrets}/original.yaml";
        restartUnits = [ "sops-activation-probe.service" ];
      };
      systemd.services.sops-activation-probe = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          cat ${config.sops.secrets.activation-probe.path} >/run/sops-activation-value
        '';
      };
      specialisation.rotated-secret.configuration.sops.secrets.activation-probe.sopsFile =
        lib.mkForce "${secrets}/rotated.yaml";
    };

  # Run switches after the other subtests, which depend on the initial system
  testScript = lib.mkAfter ''
    with subtest("systemd activation restarts a secret consumer only when its secret changes"):
        from datetime import timedelta

        station.succeed("systemctl cat sops-install-secrets.service")
        station.wait_for_unit("sops-activation-probe.service")
        assert station.succeed("cat /run/sops-activation-value").strip() == "original"
        original_system = station.succeed("readlink -f /run/current-system").strip()

        def secret_invocation():
            return station.succeed("systemctl show -p InvocationID --value sops-activation-probe.service").strip()

        def switch_secrets(system):
            output = station.succeed(f"{system}/bin/switch-to-configuration test 2>&1")
            assert "activation-restart-list" not in output, output
            assert "activation-reload-list" not in output, output
            station.wait_for_unit("sops-install-secrets.service")

        invocation = secret_invocation()
        switch_secrets(f"{original_system}/specialisation/rotated-secret")
        station.wait_until_succeeds("grep -qx rotated /run/sops-activation-value", timeout=timedelta(seconds=30))
        assert secret_invocation() != invocation, "the consumer did not restart"

        invocation = secret_invocation()
        switch_secrets(f"{original_system}/specialisation/rotated-secret")
        assert secret_invocation() == invocation, "an unchanged secret restarted its consumer"

        switch_secrets(original_system)
        station.wait_until_succeeds("grep -qx original /run/sops-activation-value", timeout=timedelta(seconds=30))
        assert secret_invocation() != invocation, "the rollback did not restart the consumer"
        station.succeed("test -z \"$(systemctl list-units --failed --no-legend --all)\"")
  '';
}
