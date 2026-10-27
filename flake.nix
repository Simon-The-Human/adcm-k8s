{
  description = "ADCM K8s Dev Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        cfg = {
          namespace = "adcm-sandbox";
          manifestsPath = "./manifests";
          nodePort = "30080";
        };
        upScript = pkgs.writeShellApplication {
          name = "adcm-up";
          runtimeInputs = [
            pkgs.minikube
            pkgs.kubectl
          ];
          text = ''
            echo "🔍 Checking Minikube status..."
            if ! minikube status | grep -q "Running"; then
              echo "⚙️ Starting Minikube with Docker driver..."
              minikube start --driver=docker
            fi

            if ! docker image inspect adcm-log-rotator:latest >/dev/null 2>&1; then
              echo "⚙️ adcm-log-rotator:latest image not found in Docker. Building from Dockerfile.rotator..."
              docker build -t adcm-log-rotator:latest -f Dockerfile.rotator .
            else
              echo "✅ Образ adcm-log-rotator:latest exists."
            fi

            echo "📦 Applying Kubernetes manifests..."
            kubectl apply -f manifests/

            # Получаем реальный IP контейнера Minikube в сети Docker
            MINIKUBE_IP=$(minikube ip)

            echo ""
            echo "✨ Sandbox is up and running!"
            echo "🌐 Access ADCM via cluster network node: http://$MINIKUBE_IP:30080"
          '';
        };
        downScript = pkgs.writeShellApplication {
          name = "adcm-down";
          runtimeInputs = [ pkgs.kubectl ];
          text = ''
            echo "🧹 Destroying resources in namespace ${cfg.namespace}..."
            kubectl delete -f ${cfg.manifestsPath}/ --ignore-not-found=true
            echo "✨ Sandbox resources cleaned up."
          '';
        };

        # 3. Скрипт проверки статуса
        statusScript = pkgs.writeShellApplication {
          name = "adcm-status";
          runtimeInputs = [
            pkgs.minikube
            pkgs.kubectl
          ];
          text = ''
            echo "📊 Cluster Status:"
            minikube status
            echo ""
            echo "📦 Pods in ${cfg.namespace}:"
            kubectl get all -n ${cfg.namespace}
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Kubernetes стек
            kubectl
            minikube
            kubernetes-helm
            k9s

            # Python-окружение для написания скриптов и обвязок
            python3
            python3Packages.pip
            python3Packages.pydantic
            python3Packages.pytest

            # Утилиты для работы с конфигурациями
            yq-go
            jq
          ];

          shellHook = ''
            echo "🚀 ADCM K8s Sandbox Environment activated!"
            echo "Target OS: $(uname -s) / Architecture: $(uname -m)"

            # Локальный kubeconfig внутри проекта, чтобы не мусорить в системе
            mkdir -p $PWD/.kube
            export KUBECONFIG=$PWD/.kube/config

            # Быстрая проверка версий инструментов
            echo "-> kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
            echo "-> minikube: $(minikube version --short)"
          '';
        };
        apps = {
          default = self.apps.${system}.up;
          up = {
            type = "app";
            program = "${upScript}/bin/adcm-up";
          };
          down = {
            type = "app";
            program = "${downScript}/bin/adcm-down";
          };
          status = {
            type = "app";
            program = "${statusScript}/bin/adcm-status";
          };
        };
      }
    );
}
