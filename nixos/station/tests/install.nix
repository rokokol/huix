{
  pkgs,
  inputs,
  system,
  ...
}@args:

# The installer image booted in VMs with OVMF, on demand and not in the flake's checks:
# `nix build .#station-install-test -L`. One VM installs the station onto a blank SATA disk with
# the real disk's model and serial, powers off, and boots from that disk. Others boot the image
# where it must refuse, and their disks are compared with blank ones afterwards. The first one
# boots it from a stick that Ventoy wrote, up to the countdown. The installed
# system is the station with the changes of fixture-host.nix and the test backdoor; the image is
# the one the flake builds for that system, with the backdoor too, and its secrets are added by
# make-station-iso.sh itself
let
  station = inputs.self.nixosConfigurations.nixos-station;
  inherit (pkgs) lib;
  qemu-common = import "${inputs.nixpkgs}/nixos/lib/qemu-common.nix" { inherit (pkgs) lib stdenv; };
  instrumentation = "${inputs.nixpkgs}/nixos/modules/testing/test-instrumentation.nix";

  stationMac = "52:54:00:12:01:03";
  fixtures = import ./fixtures.nix {
    inherit pkgs;
    pcMac = "52:54:00:12:01:01";
  };

  target = station.extendModules {
    modules = [
      (import ./fixture-host.nix { inherit fixtures stationMac; })
      instrumentation
    ];
  };
  disk = lib.head (lib.attrValues target.config.disko.devices.disk);

  # The ATA identity the station's disk reports. udev names a SATA disk ata-<model>_<serial>,
  # with the spaces of the model turned into underscores; the check below holds these two to
  # the path disko.nix declares, and the install only starts when udev made that path
  model = "KINGSTON SUV400S37120G";
  serial = "50026B726605FC01";
  diskId = "/dev/disk/by-id/ata-${lib.replaceStrings [ " " ] [ "_" ] model}_${serial}";
  # 111.8 GiB, the size of the real disk; the image file grows only with what is written
  diskBytes = 120034123776;

  # The image without secrets, exactly as `nix build .#station-installer` makes it but for the
  # backdoor and the target. mk-image.nix passes its arguments on as specialArgs, where pkgs
  # would replace the image's own
  plain =
    (import ../installer/mk-image.nix (builtins.removeAttrs args [ "pkgs" ]) {
      inherit target;
      modules = [ instrumentation ];
    }).config.system.build.isoImage;
  plainIso = "${plain}/iso/${plain.isoName}";

  makeIso = import ../installer/make-iso.nix { inherit pkgs inputs; };

  # The fixture Tailscale state: an empty state store, which tailscaled reads as a node that
  # never logged in, and a marker that shows the contents of ts-state/ arrived
  secretsIso =
    pkgs.runCommand "station-installer-test-with-secrets.iso"
      {
        nativeBuildInputs = [ makeIso ];
        meta.description = "The test's installer image with fixture secrets added by make-station-iso";
      }
      ''
        mkdir -p secrets/ts-state
        cp ${fixtures}/key.txt secrets/age-key.txt
        printf '{}\n' >secrets/ts-state/tailscaled.state
        printf 'fixture\n' >secrets/ts-state/fixture-marker
        tar -C secrets -cf secrets/tailscale-state.tar ts-state
        rm -r secrets/ts-state
        # The script refuses the store, so it writes here and the file moves after
        make-station-iso write -s secrets ${plainIso} "$PWD/station.iso"
        mv station.iso $out
      '';

  # The owner boots the image from a Ventoy stick. nixpkgs marks Ventoy unfree and insecure for
  # the binary blobs it ships; this instance permits it alone, and it runs only inside the VM
  # that writes the stick image
  inherit
    (import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfreePredicate = drv: lib.getName drv == "ventoy";
        allowInsecurePredicate = drv: lib.getName drv == "ventoy";
      };
    })
    ventoy
    ;
  # Ventoy boots this image after 5 s with no menu in between. On the owner's stick, with no
  # such file, he picks the image in Ventoy's menu himself
  ventoyJson = builtins.toJSON {
    control = [
      { VTOY_DEFAULT_IMAGE = "/station.iso"; }
      { VTOY_MENU_TIMEOUT = "5"; }
      { VTOY_SECONDARY_BOOT_MENU = "0"; }
    ];
  };

  # What the installed disk must hold, read from the host's disko configuration
  layout = lib.mapAttrsToList (_: part: {
    inherit (part) label size;
    fstype = if part.content.type == "filesystem" then part.content.format else part.content.type;
    mountpoints =
      if part.content ? subvolumes then
        lib.mapAttrsToList (_: sub: sub.mountpoint) part.content.subvolumes
      else
        [ part.content.mountpoint ];
  }) disk.content.partitions;
in
assert lib.assertMsg (
  diskId == disk.device
) "the test disk would appear as ${diskId}, and the host installs onto ${disk.device}";
pkgs.testers.runNixOSTest {
  name = "station-install";

  imports = [
    (import ./test-meta.nix {
      inherit lib;
      description = "Install nixos-station from its installer image in a VM, and refuse where it must";
    })
  ];

  # Writes a Ventoy stick image with the test's image on it; the other machines are made by the
  # test script, as they boot images and disks rather than a NixOS configuration
  nodes.maker = {
    virtualisation = {
      memorySize = 2048;
      emptyDiskImages = [ 4096 ];
    };
    boot.supportedFilesystems = [ "exfat" ];
    environment.systemPackages = [ ventoy ];
  };

  testScript = ''
    import json
    import shlex
    import subprocess
    import tempfile
    import time
    from datetime import timedelta
    from pathlib import Path

    qemu_img = "${pkgs.qemu_test}/bin/qemu-img"
    disk_id = "${diskId}"
    log_path = "/run/station-install.log"
    layout = json.loads(${builtins.toJSON (builtins.toJSON layout)})
    work = Path(tempfile.mkdtemp(prefix="station-install-"))

    def blank(name, size):
        path = work / f"{name}.qcow2"
        subprocess.run([qemu_img, "create", "-q", "-f", "qcow2", str(path), str(size)], check=True)
        return path

    def efi_vars(name):
        path = work / f"{name}-vars.fd"
        path.write_bytes(Path("${pkgs.OVMF.variables}").read_bytes())
        return path

    # One SATA disk on an AHCI controller, and the image as a USB stick, as on the station. Not
    # named machine: the driver binds that name when a test has a single node
    def vm(name, disk, serial, iso=None, uefi=True, memory=2048, vars=None, iso_format="raw"):
        # qemuBinary is the binary with its machine and CPU flags, as one string
        flags = shlex.split("${qemu-common.qemuBinary pkgs.qemu_test}") + [
            "-m", str(memory), "-smp", "4",
            "-netdev", "user,id=net0",
            "-device", "virtio-net-pci,netdev=net0,mac=${stationMac}",
            "-device", "ahci,id=ahci",
            "-drive", f"if=none,id=disk,format=qcow2,file={disk}",
            "-device", f"ide-hd,drive=disk,bus=ahci.0,model=${model},serial={serial},bootindex=2",
        ]
        if iso is not None:
            flags += [
                "-device", "qemu-xhci",
                "-drive", f"if=none,id=stick,format={iso_format},readonly=on,file={iso}",
                "-device", "usb-storage,drive=stick,bootindex=1",
            ]
        if uefi:
            flags += [
                "-drive", "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
                "-drive", f"if=pflash,format=raw,unit=1,file={vars or efi_vars(name)}",
            ]
        m = create_machine(" ".join(shlex.quote(f) for f in flags), name=name)
        # The driver's cleanup releases only the machines it lists. Without this, a failed run
        # leaves these running and the build waits for the global timeout
        driver.machines_qemu.append(m)
        return m

    def install_log(m):
        return m.succeed(f"cat {log_path}")

    # On a timeout the log and the unit's journal say why, before the error ends the test
    def wait_for_log(m, text, minutes=5):
        try:
            m.wait_until_succeeds(f"grep -qF {shlex.quote(text)} {log_path}", timeout=timedelta(minutes=minutes))
        except Exception:
            print(m.execute(f"cat {log_path}; journalctl -b -u station-install.service")[1])
            raise

    # A refusal leaves the unit running a root shell on tty1, and the machine on
    def assert_refused(m, *facts):
        log = install_log(m)
        for fact in facts:
            assert fact in log, f"{m.name}: {fact!r} is not in the log:\n{log}"
        assert "Nothing was touched" in log, f"{m.name}: the log does not say the disk is untouched:\n{log}"
        m.succeed("systemctl is-active station-install.service")
        m.succeed("pgrep -t tty1 -x bash")

    def assert_blank(path, size):
        reference = blank(f"{path.stem}-reference", size)
        result = subprocess.run([qemu_img, "compare", "-q", str(reference), str(path)])
        assert result.returncode == 0, f"{path.name} is no longer blank"

    small = 2 * 1024**3

    with subtest("the image boots from a Ventoy stick and finds its secrets there"):
        maker.start()
        maker.succeed("printf 'y\\ny\\n' | ventoy -I /dev/vdb")
        maker.succeed("mkdir -p /stick && mount /dev/vdb1 /stick")
        maker.succeed("cp ${secretsIso} /stick/station.iso")
        maker.succeed("mkdir -p /stick/ventoy")
        maker.succeed(f"printf '%s' {shlex.quote(${builtins.toJSON ventoyJson})} >/stick/ventoy/ventoy.json")
        maker.succeed("umount /stick && sync")
        maker.shutdown()
        stick = maker.state_dir / "empty0.qcow2"
        ventoy_disk = blank("ventoy", small)
        m = vm("ventoy", ventoy_disk, "${serial}", iso=stick, iso_format="qcow2")
        m.start()
        wait_for_log(m, "Press any key", minutes=10)
        log = install_log(m)
        print(log)
        assert "The installer stopped" not in log, f"the countdown stopped before any key:\n{log}"
        m.send_key("a")
        wait_for_log(m, "Nothing was touched", minutes=1)
        assert_refused(m, "A key stopped")
        m.shutdown()
        assert_blank(ventoy_disk, small)

    disks = {
        "wrong_disk": blank("wrong-disk", small),
        "plain": blank("plain", small),
        "aborted": blank("aborted", small),
        "bios": blank("bios", small),
    }
    refusals = {
        "wrong_disk": vm("wrong_disk", disks["wrong_disk"], "0000NOTTHESTATION", iso="${secretsIso}"),
        "plain": vm("plain", disks["plain"], "${serial}", iso="${plainIso}"),
        "aborted": vm("aborted", disks["aborted"], "${serial}", iso="${secretsIso}"),
        "bios": vm("bios", disks["bios"], "${serial}", iso="${secretsIso}", uefi=False),
    }
    for m in refusals.values():
        m.start()

    with subtest("a machine without the station's disk is left alone"):
        m = refusals["wrong_disk"]
        wait_for_log(m, "Nothing was touched")
        m.fail(f"test -e {disk_id}")
        assert_refused(m, disk_id, "not that machine")

    with subtest("the image without secrets installs nothing"):
        m = refusals["plain"]
        wait_for_log(m, "Nothing was touched")
        m.succeed(f"test -b {disk_id}")
        assert_refused(m, "station-secrets")

    with subtest("a key in the countdown stops the install"):
        m = refusals["aborted"]
        wait_for_log(m, "Press any key")
        log = install_log(m)
        assert "KINGSTON" in log and disk_id in log, f"the countdown does not name the disk:\n{log}"
        assert "The installer stopped" not in log, f"the countdown stopped before any key:\n{log}"
        m.send_key("a")
        wait_for_log(m, "Nothing was touched", minutes=1)
        assert_refused(m, "A key stopped")

    with subtest("a machine booted in BIOS mode is refused"):
        m = refusals["bios"]
        wait_for_log(m, "Nothing was touched")
        m.fail("test -d /sys/firmware/efi")
        assert_refused(m, "UEFI")

    with subtest("every refused disk is still blank"):
        for name, m in refusals.items():
            m.shutdown()
            assert_blank(disks[name], small)

    station_disk = blank("station", ${toString diskBytes})
    station_vars = efi_vars("station")

    with subtest("the image installs the station and powers off"):
        installer = vm("installer", station_disk, "${serial}", iso="${secretsIso}", memory=3800, vars=station_vars)
        started = time.monotonic()
        installer.start()
        wait_for_log(installer, "Press any key")
        countdown = time.monotonic()
        installer.wait_until_succeeds(
            f"grep -qE 'The station is installed|The installer stopped' {log_path}",
            timeout=timedelta(minutes=60),
        )
        log = install_log(installer)
        assert "The station is installed" in log, f"the install failed:\n{log}"
        installer.wait_for_shutdown()
        print(f"boot to countdown {countdown - started:.0f} s, countdown to power-off {time.monotonic() - countdown:.0f} s")
        used = subprocess.run([qemu_img, "info", "--output=json", str(station_disk)], check=True, capture_output=True)
        print(f"the installed disk image holds {json.loads(used.stdout)['actual-size'] / 1024**3:.1f} GiB")

    station = vm("station", station_disk, "${serial}", memory=3800, vars=station_vars)
    station.start()
    station.wait_for_unit("multi-user.target")

    with subtest("the station boots from its own disk"):
        station.fail("findmnt /iso")
        source = station.succeed("findmnt -no SOURCE /").strip()
        root_label = next(part["label"] for part in layout if "/" in part["mountpoints"])
        system_part = station.succeed(f"readlink -f /dev/disk/by-partlabel/{root_label}").strip()
        assert source.startswith(system_part), f"/ is {source}, not on {system_part}"
        station.succeed("test -d /sys/firmware/efi")

    with subtest("the partitions and file systems are the ones disko declares"):
        for part in layout:
            dev = station.succeed(f"readlink -f /dev/disk/by-partlabel/{part['label']}").strip()
            assert dev.startswith(station.succeed(f"readlink -f {disk_id}").strip()), f"{part['label']} is not on {disk_id}"
            fstype = station.succeed(f"blkid -o value -s TYPE {dev}").strip()
            assert fstype == part["fstype"], f"{part['label']} is {fstype}, not {part['fstype']}"
            if part["size"].endswith("G"):
                size = int(station.succeed(f"lsblk -bdno SIZE {dev}"))
                assert size == int(part["size"][:-1]) * 1024**3, f"{part['label']} has {size} bytes, not {part['size']}"
            for mountpoint in part["mountpoints"]:
                mounted = station.succeed(f"findmnt -no FSTYPE,SOURCE {mountpoint}").split()
                assert mounted[0] == part["fstype"] and mounted[1].startswith(dev), f"{mountpoint} is {mounted}"
        assert len(layout) == 3, f"disko declares {len(layout)} partitions"
        station.succeed(f"test $(lsblk -nro TYPE {disk_id} | grep -c part) -eq 3")

    with subtest("/srv/backup is mounted btrfs"):
        station.succeed("findmnt -no FSTYPE /srv/backup | grep -qx btrfs")

    with subtest("the age key is in place, and sops-nix decrypts with it"):
        station.succeed("test \"$(stat -c '%a %u %g' /var/lib/sops-nix/key.txt)\" = '600 0 0'")
        station.succeed("test \"$(stat -c '%a %u %g' /var/lib/sops-nix)\" = '700 0 0'")
        station.succeed("test -s /run/secrets-for-users/rokokol-password-hash")
        station.succeed("test -s /run/secrets/pc-mac")

    with subtest("the Tailscale state is the contents of ts-state, readable by root alone"):
        station.succeed("test \"$(stat -c '%a %u %g' /var/lib/tailscale)\" = '700 0 0'")
        station.succeed("test -f /var/lib/tailscale/tailscaled.state")
        station.succeed("test -f /var/lib/tailscale/fixture-marker")
        station.fail("test -e /var/lib/tailscale/ts-state")
        station.succeed("test -z \"$(find /var/lib/tailscale -perm /077)\"")
        station.wait_for_unit("tailscaled.service")

    with subtest("no unit is failed"):
        station.wait_for_unit("systemd-networkd-wait-online.service")
        station.succeed("test -z \"$(systemctl list-units --failed --no-legend --all)\"")

    station.shutdown()
  '';
}
