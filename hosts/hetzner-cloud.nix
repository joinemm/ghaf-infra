{
  modulesPath,
  self,
  inputs,
  lib,
  machines,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    self.nixosModules.service-monitoring
  ];

  services.monitoring.logs.lokiAddress = lib.mkDefault "http://${machines.ghaf-monitoring.internal_ip}:3100";

  hardware.enableRedistributableFirmware = true;
  networking.useDHCP = true;

  # hetzner internal network
  networking.firewall.trustedInterfaces = [ "eth1" ];

  boot = {
    # use predictable network interface names (eth0)
    kernelParams = [ "net.ifnames=0" ];

    # grub boot loader with EFI
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
