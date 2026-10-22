{
  description = "ADCM K8s Dev Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          kubectl
          minikube
          kubernetes-helm
          k9s
          python311
          python311Packages.pip
        ];

        shellHook = ''
          echo "🚀 ADCM Kubernetes Dev Environment initialized!"
          export KUBECONFIG=$PWD/.kube/config
        '';
      };
    };
}
