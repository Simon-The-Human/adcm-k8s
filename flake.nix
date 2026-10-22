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
      }
    );
}
