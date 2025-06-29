# SPDX-FileCopyrightText: 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  self,
  inputs,
  lib,
  ...
}:
{
  imports =
    [
      ./ficolo-disk-config.nix
      inputs.disko.nixosModules.disko
    ]
    ++ (with self.nixosModules; [
      common
      ficolo-common
    ]);

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "megaraid_sas"
      "nvme"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  services.monitoring = {
    metrics.enable = true;
    logs.enable = true;
  };

  nix.settings = {
    cores = 24;
    max-jobs = 16;
  };
}
