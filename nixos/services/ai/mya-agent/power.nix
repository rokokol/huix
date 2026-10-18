{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The agent puts a workstation to sleep, locks it, darkens its screen, turns it off or restarts
# it. Its guest user there may start one unit for each of these and nothing else; the units run
# as root, and the screen's as the owner, whose Hyprland it is
let
  agent = config.rokokol.mya-agent;
  inherit (agent) guest;
  hyprctl = lib.getExe' config.programs.hyprland.package "hyprctl";

  # Exits 0 when every session of the owner on this host is idle, and names the busy ones
  # otherwise. logind judges a terminal by its last input, and hypridle marks the desktop
  idle = pkgs.writeShellApplication {
    name = "mya-power-idle";
    runtimeInputs = with pkgs; [
      jq
      systemd
    ];
    text = ''
      busy=0
      for session in $(loginctl list-sessions -j | jq -r --arg owner ${guest.owner} \
        '.[] | select(.user == $owner and .class == "user") | .session'); do
        if [ "$(loginctl show-session "$session" -p IdleHint --value)" != yes ]; then
          echo "${guest.owner} is active in session $session ($(loginctl show-session "$session" -p Type --value))"
          busy=1
        fi
      done
      exit "$busy"
    '';
  };
  # What turns the host off waits until the owner is away
  whenIdle = {
    ExecStartPre = lib.getExe idle;
  };

  actions = {
    suspend = whenIdle // {
      ExecStart = "${pkgs.systemd}/bin/systemctl suspend";
    };
    # Every lock goes through logind, which hyprlock answers
    lock = {
      ExecStart = "${pkgs.systemd}/bin/loginctl lock-sessions";
    };
    # The unit has no session, so it names the runtime directory where hyprctl finds Hyprland
    screen-off = {
      User = guest.owner;
      ExecStart = pkgs.writeShellScript "mya-power-screen-off" ''
        XDG_RUNTIME_DIR=/run/user/$(id -u) exec ${hyprctl} -i 0 dispatch 'hl.dsp.dpms({ action = "off" })'
      '';
    };
    poweroff = whenIdle // {
      ExecStart = "${pkgs.systemd}/bin/systemctl poweroff";
    };
    reboot = whenIdle // {
      ExecStart = "${pkgs.systemd}/bin/systemctl reboot";
    };
  };
  unitOf = action: "mya-power-${action}.service";
in
{
  options.rokokol.mya-agent = {
    power.enable =
      lib.mkEnableOption "the skill that wakes, puts to sleep, locks and turns off the workstations"
      // {
        default = agent.enable;
        defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
      };

    guest.power.enable =
      lib.mkEnableOption "the units that let the guest put this host to sleep, lock it and turn it off"
      // {
        default = guest.enable;
        defaultText = lib.literalExpression "config.rokokol.mya-agent.guest.enable";
      };
  };

  config = lib.mkMerge [
    (lib.mkIf agent.power.enable {
      rokokol.mya-agent.plugins = [
        (builtins.path {
          name = "power-plugin";
          path = "${inputs.self}/nixos/services/ai/mya-agent/plugins/power";
        })
      ];
    })

    (lib.mkIf guest.power.enable {
      assertions = [
        {
          assertion = guest.owner != null;
          message = "rokokol.mya-agent.guest.power needs guest.owner, whose screen it turns off";
        }
      ];

      # The agent asks before it starts a unit that would only refuse
      rokokol.mya-agent.packages = [ idle ];

      systemd.services = lib.mapAttrs' (
        action: serviceConfig:
        lib.nameValuePair "mya-power-${action}" {
          description = "Power action ${action}, for the agent's guest";
          serviceConfig = {
            Type = "oneshot";
          }
          // serviceConfig;
        }
      ) actions;

      security.polkit = {
        enable = true;
        extraConfig = ''
          // The guest starts the power units, and only starts them
          polkit.addRule(function (action, subject) {
            var units = ${builtins.toJSON (map unitOf (lib.attrNames actions))};
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                subject.user == "${agent.user}" &&
                action.lookup("verb") == "start" &&
                units.indexOf(action.lookup("unit")) >= 0) {
              return polkit.Result.YES;
            }
          });
        '';
      };
    })
  ];
}
