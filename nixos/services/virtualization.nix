{ pkgs, rokokolName, ... }:

{
  boot = {
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
    ];

    kernelModules = [
      "kvm-amd"
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
      "vfio_virqfd"
    ];
  };
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  users.users.${rokokolName} = {
    extraGroups = [
      "libvirtd"
    ];
  };

  systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = pkgs.lib.mkForce [
    ""
    "/bin/sh -c \"umask 0077 && if [ ! -f /var/lib/libvirt/secrets/secrets-encryption-key ]; then dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key; fi\""
  ];
}
