{
  description = "rokkitpokkit development environment - For pocket computers";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core build orchestration
            mkosi
            
            # EROFS image tools
            erofs-utils
            
            # Container/image tools
            podman
            skopeo
            
            # Deduplication and chunking (casync)
            casync
            
            # Version control and scripting
            git
            bash
            
            # Build tools
            gcc
            binutils
            pkg-config
            gnumake
            
            # Python with pip to install pefile
            python3
            python3Packages.pip
            python3Packages.pyyaml
            
            # B2 and cloud tooling
            backblaze-b2
            
            # Kubernetes/manifests
            kubectl
            kustomize
            
            # Development utilities
            curl
            wget
            jq
            openssl
            
            # Sudo for mkosi
            sudo
          ];

          shellHook = ''
            echo "rokkitpokkit development environment loaded"
            echo ""
            echo "Build commands:"
            echo "  sudo mkosi -f --profile phosh,rawhide,droid-juicer,precompile-akmods,ostree"
            echo "  COMPOSE_ENABLE_PUBLISH=0 COMPOSE_USE_SUDO=1 ./scripts/casync-compose.sh"
            echo "  BOOT_PROFILE_CLI=./.tools/fastboop-cli ./scripts/bootprofile-channel.sh"
            echo ""
            echo "mkosi profiles available:"
            echo "  - phosh (Phosh mobile shell)"
            echo "  - ostree (Immutable ostree filesystem)"
            echo "  - droid-juicer (Android firmware extraction)"
            echo "  - sdm845-embedded-firmware (Snapdragon 845 firmware blobs)"
            echo "  - rawhide (Fedora Rawhide target)"
          '';
        };
      }
    );
}

