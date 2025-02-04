{
  description = "HyperAST";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        filter = inputs.nix-filter.lib;
        hyperast-backend = pkgs.rustPlatform.buildRustPackage {
            pname = "HyperAST-WebAPI";
            version = "0.1.0";
            src = filter {
              root = ./.;
              exclude = [
                ./.vscode
                ./.github/workflows
                ./.direnv
                ./target
                ./flake.lock
                ./flake.nix
                ./LICENCES
                ./README.md
              ];

            };
            buildAndTestSubdir = "client";
            OPENSSL_NO_VENDOR = 1;
            release = true;
            doCheck = false;
            buildInputs = with pkgs; [
              # misc libraries
              openssl
            ];
            nativeBuildInputs = with pkgs; [
              # misc libraries
              cmake
              pkg-config
              
              # Rust
              (rust-bin.fromRustupToolchainFile ./rust-toolchain)
            ];
            cargoLock = {
              lockFile = ./Cargo.lock;
              allowBuiltinFetchGit = true;
            };
          };
      in
      {
        apps = {
          hyperast-webapi = {
            type = "app";
            program = "${hyperast-backend}/bin/client";
          };
        };

        packages = rec {
          hyperast-webapi = hyperast-backend;

          _hyperast-webapi-dockerImage = pkgs.dockerTools.buildImage {
            name = "HyperAST-Backend1111";
            tag = "0.2.0";
            config = {
              Cmd = [ "${hyperast-backend}/bin/client -- 0.0.0.0:8000" ];
            };
          };

          hyperast-webapi-dockerImage = pkgs.dockerTools.buildImage {
            name = "HyperAST-Backend2222";
            tag = "0.2.0";
            fromImage = _hyperast-webapi-dockerImage;
            runAsRoot = ''
              mkdir -p /bin/
              echo "echo aa" > /bin/test.sh
            '';
            
            config = {
              Cmd = [ "${hyperast-backend}/bin/client -- 0.0.0.0:8000" ];
            };
          };
        };

        devShell = pkgs.mkShell rec {
          buildInputs = with pkgs; [
            # Rust 
            (rust-bin.fromRustupToolchainFile ./rust-toolchain)
            trunk
            
            # misc
            cmake
            pkg-config

            # Nix
            nixfmt
          ];
          libraries = with pkgs; [
            # x11 libraries
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            xorg.libX11

            # wayland libraries
            wayland
            
            # GUI libraries
            libxkbcommon
            libGL
            fontconfig

            # misc libraries
            openssl
          ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libraries;
        };
      }
    );
}
