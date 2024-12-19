# SPDX-FileCopyrightText: 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  self,
  config,
  inputs,
  modulesPath,
  lib,
  ...
}:
{
  imports =
    [
      ./disk-config.nix
      (modulesPath + "/profiles/qemu-guest.nix")
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
      inputs.buildbot-nix.nixosModules.buildbot-master
      inputs.buildbot-nix.nixosModules.buildbot-worker
    ]
    ++ (with self.nixosModules; [
      common
      service-openssh
      user-jrautiola
    ]);

  system.stateVersion = lib.mkForce "24.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.enableRedistributableFirmware = true;

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      github_app_secret.owner = "buildbot";
      github_oauth_secret.owner = "buildbot";
      github_webhook_secret.owner = "buildbot";
      worker-password.owner = "buildbot";
      workersfile.owner = "buildbot";
    };
  };

  networking = {
    hostName = "buildbot";
    useDHCP = true;
  };

  boot = {
    # use predictable network interface names (eth0)
    kernelParams = [ "net.ifnames=0" ];
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
