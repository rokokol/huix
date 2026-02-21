{ ... }:

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
}
