# SPDX-FileCopyrightText: 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  perSystem =
    {
      pkgs,
      inputs',
      config,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        shellHook = ''
          ${config.pre-commit.installationScript}
          FLAKE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
          if [ -z "$FLAKE_ROOT" ]; then
            echo "WARNING: flake root not round; skipping helpers installation."
            return
          fi
          prefetch-plugins () {
            conf_path="$1"
            if [ -z "$conf_path" ]; then
              echo "Error: missing first argument - expecting relative path to host configuration"
              return
            fi
            python "$FLAKE_ROOT"/scripts/resolve_plugins.py \
              --jenkins-version ${pkgs.jenkins.version} \
              --plugins-file "$FLAKE_ROOT"/"$conf_path"/plugins.txt \
              --output "$FLAKE_ROOT"/"$conf_path"/plugins.json
          }
          echo ""
          echo 1>&2 "Welcome to the development shell!"
          echo ""
          echo "This shell provides following helper commands:"
          echo " - prefetch-plugins hosts/azure/jenkins-controller"
          echo " - prefetch-plugins hosts/hetzci/release"
          echo " - prefetch-plugins hosts/hetzci/prod"
          echo " - prefetch-plugins hosts/hetzci/dev"
          echo " - prefetch-plugins hosts/hetzci/vm"
          echo ""
        '';

        packages =
          (with pkgs; [
            go
            azure-cli
            git
            jq
            nix
            nixfmt-rfc-style
            nixos-rebuild
            nixos-anywhere
            python3.pkgs.black
            python3.pkgs.colorlog
            python3.pkgs.deploykit
            python3.pkgs.invoke
            python3.pkgs.pycodestyle
            python3.pkgs.pylint
            python3.pkgs.tabulate
            python3.pkgs.aiohttp
            reuse
            sops
            ssh-to-age
            wget
            terragrunt
            nebula
            (terraform.withPlugins (p: [
              # We need to override the azurerm version to fix the issue described
              # in https://ssrc.atlassian.net/browse/SP-4926.
              # TODO:
              # Below override is no longer needed when the azurerm version we
              # get from the nixpkgs pinned in ghaf-infra flake includes a fix for
              # https://github.com/hashicorp/terraform-provider-azurerm/issues/24444.
              # At the time of writing, ghaf-infra flake pins to
              # nixos-24.05, that ships with azurerm v3.97.1 which is broken.
              # For more information on the available azurerm versions, see:
              # https://registry.terraform.io/providers/hashicorp/azurerm.
              (p.azurerm.override {
                owner = "hashicorp";
                repo = "terraform-provider-azurerm";
                rev = "v3.85.0";
                hash = "sha256-YXVSApUnJlwxIldDoijl72rA9idKV/vGRf0tAiaH8cc=";
                vendorHash = null;
              })
              p.external
              p.local
              p.null
              p.random
              p.secret
              p.sops
              p.tls
              p.sops
            ]))
          ])
          ++ (with inputs'; [
            nix-fast-build.packages.default
            deploy-rs.packages.default
          ])
          ++ [
            (pkgs.writeShellScriptBin "deploy-diff" ''
              set -eou pipefail

              host="$1"
              shift 1
              trap 'rm wait.fifo' EXIT
              mkfifo wait.fifo

              deploy "$@" --debug-logs --dry-activate ".#$host" 2>&1 \
                | tee >(grep -v DEBUG) >(grep 'activate-rs --debug-logs activate' | \
                    sed -e 's/^.*activate-rs --debug-logs activate \(.*\) --profile-user.*$/\1/' | \
                    xargs -I% bash -xc "ssh $host 'nix diff /run/current-system %'" ; echo >wait.fifo) \
                >/dev/null

              read <wait.fifo
            '')
          ];
      };
    };
}
