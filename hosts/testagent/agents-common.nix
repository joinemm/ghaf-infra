# SPDX-FileCopyrightText: 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0

{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  # Vendored in, as brainstem isn't suitable for nixpkgs packaging upstream:
  # https://github.com/NixOS/nixpkgs/pull/313643
  brainstem = pkgs.callPackage ../../pkgs/brainstem { };

  connect-script = pkgs.writeShellApplication {
    name = "connect";
    text = # sh
      ''
        url="''${1%/}"  # Remove trailing slash

        if [[ ! $url =~ ^https?://[^/]+$ ]]; then
          echo "ERROR: The URL should start with https and not have any subpath"
          exit 1
        fi

        if [[ ! -f /var/lib/jenkins/jenkins.env ]]; then
          # create the file with correct permissions
          sudo install -o jenkins -g jenkins -m 600 /dev/null /var/lib/jenkins/jenkins.env
        fi

        # add this controller to known hosts
        sudo -u jenkins bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        sudo -u jenkins bash -c "ssh-keyscan ''${url#*//} >> ~/.ssh/known_hosts"

        echo "CONTROLLER=$url" | sudo tee /var/lib/jenkins/jenkins.env
        sudo systemctl restart start-agents.service

        echo "Connected agents to the controller"
      '';
  };

  disconnect-script = pkgs.writeShellApplication {
    name = "disconnect";
    text = # sh
      ''
        sudo systemctl stop start-agents.service
        echo "CONTROLLER=" | sudo tee /var/lib/jenkins/jenkins.env

        echo "Disconnected agents from the controller"
      '';
  };
in
{
  sops.secrets =
    let
      credential = {
        sopsFile = ./credentials.yaml;
        owner = "jenkins";
      };
    in
    {
      dut-pass = credential;
      plug-login = credential;
      plug-pass = credential;
      switch-token = credential;
      switch-secret = credential;
      wifi-ssid = credential;
      wifi-password = credential;
      pi-login = credential;
      pi-pass = credential;
      # used for ssh connections
      ssh_host_ed25519_key.owner = "jenkins";
    };

  services.udev.packages = [
    brainstem
    pkgs.usbsdmux
  ];

  environment.systemPackages =
    [
      inputs.robot-framework.packages.${pkgs.system}.ghaf-robot
      brainstem
    ]
    ++ (with pkgs; [
      minicom
      usbsdmux
      grafana-loki
      (python3.withPackages (ps: with ps; [ pyserial ]))
      connect-script
      disconnect-script
    ]);

  # The Jenkins slave service is very barebones
  # it only installs java and sets up jenkins user
  services.jenkinsSlave.enable = true;

  # Jenkins needs sudo and serial rights to perform the HW tests
  users.users.jenkins.extraGroups = [
    "wheel"
    "dialout"
    "tty"
  ];

  # This server is only exposed to the internal network
  # fail2ban only causes issues here
  services.fail2ban.enable = lib.mkForce false;

  systemd.services =
    let
      # Helper function to create agent services for each hardware device
      mkAgent = device: {
        bindsTo = [ "start-agents.service" ];
        wantedBy = [ "start-agents.service" ];
        after = [ "start-agents.service" ];

        path =
          [
            brainstem
            inputs.robot-framework.packages.${pkgs.system}.ghaf-robot
          ]
          ++ (with pkgs; [
            curl
            wget
            jdk
            git
            bashInteractive
            coreutils
            util-linux
            nix
            zstd
            jq
            csvkit
            sudo
            openssh
            iputils
            netcat
            python3
            usbsdmux
            grafana-loki
          ]);

        serviceConfig = {
          Type = "simple";
          User = "jenkins";
          EnvironmentFile = "/var/lib/jenkins/jenkins.env";
          WorkingDirectory = "/var/lib/jenkins";
          Restart = "no";
          SuccessExitStatus = [ 6 ];
          ExecStart = toString (
            pkgs.writeShellScript "jenkins-connect.sh" # sh
              ''
                if [[ -z "$CONTROLLER" ]]; then
                  echo "ERROR: Variable CONTROLLER not configured in $(pwd)/jenkins.env"
                  exit 6
                fi

                mkdir -p "/var/lib/jenkins/agents/${device}"

                # connects to controller with ssh and grabs the jnlp file which includes the secret
                JNLP="$(
                  ssh -i ${config.sops.secrets.ssh_host_ed25519_key.path} \
                  ${config.networking.hostName}@''${CONTROLLER#*//} \
                  "curl -H 'X-Forwarded-User: ${config.networking.hostName}' http://localhost:8081/computer/${device}/jenkins-agent.jnlp"
                )"
                JENKINS_SECRET="$(echo $JNLP | sed "s/.*<application-desc><argument>\([a-z0-9]*\).*/\1\n/")"

                # opens a websocket connection to the jenkins controller from this agent
                ${pkgs.jdk}/bin/java \
                  -jar agent.jar \
                  -url "$CONTROLLER" \
                  -name "${device}" \
                  -secret "$JENKINS_SECRET" \
                  -workDir "/var/lib/jenkins/agents/${device}" \
                  -webSocket
              ''
          );
        };
      };
    in
    {
      # one agent per unique hardware device to act as a lock
      agent-orin-agx = mkAgent "orin-agx";
      agent-orin-nx = mkAgent "orin-nx";
      agent-riscv = mkAgent "riscv";
      agent-nuc = mkAgent "nuc";
      agent-lenovo-x1 = mkAgent "lenovo-x1";

      start-agents = {
        path = with pkgs; [ wget ];
        serviceConfig = {
          Type = "oneshot";
          User = "jenkins";
          RemainAfterExit = "yes";
          WorkingDirectory = "/var/lib/jenkins";
          ExecStart = toString (
            pkgs.writeShellScript "start-agents.sh" # sh
              ''
                if [[ ! -f agent.jar ]]; then
                  echo "Downloading agent.jar"
                  wget -O "$CONTROLLER/jnlpJars/agent.jar"
                fi
              ''
          );
        };
      };
    };
}
