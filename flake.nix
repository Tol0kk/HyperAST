{
  description = "HyperAST";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, crane, advisory-db, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          toolchain = fenix.packages.${system}.fromToolchainFile {
            dir = ./.;
            sha256 = "sha256-NGdi7CZp3m6s4P4KMFoVfQmeKsWhLnioYoHcF66dBzk=";
          };
          craneLib = crane.lib.${system}.overrideToolchain toolchain;
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          src = lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              (lib.hasSuffix "\.html" path) ||
              (lib.hasInfix "/assets/" path) ||
              (craneLib.filterCargoSources path type);
          };
          # Common attributes for all the packages
          commonArgs = {
            pname = "HyperAST";
            version = "0.1.0";
            inherit src;
            strictDeps = true;
            doCheck = false; # Still do the check pahse for whatever reason !!!

            # OpenSSL and Cmake dependancies
            OPENSSL_NO_VENDOR = 1;
            buildInputs = with pkgs; [
              openssl
            ];
            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake # Needed for prost-build crate
            ];
          };

          # Specific attributes for Web API construction
          WebAPIArgs = (commonArgs // {
            pname = "HyperAST-WebAPI";
            cargoExtraArgs = "--package=client";
          });

          # Specific attributes for GUI construction
          GUIArgs = (commonArgs // {
            pname = "HyperAST-GUI";
            cargoExtraArgs = "--package=hyper_app";
            CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
            trunkIndexPath = "./hyper_app/index.html";
          });

          # Cache atrifacts of cargo dependencies, usefull for caching inside CI. 
          WebAPIArgsCargoArtifacts = craneLib.buildDepsOnly WebAPIArgs;
          GUIArgsCargoArtifacts = craneLib.buildDepsOnly GUIArgs;
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          # Small script to serve hyperast-gui
          hyperast-gui-serve = pkgs.writeScriptBin "hyperast-gui-serve" ''
            ${pkgs.python3Minimal}/bin/python3 -m http.server --directory ${self.packages.${system}.hyperast-gui} $1
          '';
        in
        {
          checks =
            {
              # Check formatting
              hyperast-fmt = craneLib.cargoFmt commonArgs;

              # Audit dependencies
              hyperast-audit = craneLib.cargoAudit {
                inherit src advisory-db;
              };

              # Run Clippy on all packages and fail on warning.
              hyperast-clippy = craneLib.cargoClippy (commonArgs // {
                inherit cargoArtifacts;
                cargoClippyExtraArgs = "--all-targets -- --deny warnings";
              });
            };


          apps = {
            hyperast-webapi = {
              type = "app";
              program = "${self.packages.${system}.hyperast-webapi}/bin/client";
            };
            hyperast-gui = {
              type = "app";
              program = "${hyperast-gui-serve}/bin/hyperast-gui-serve";
            };
          };

          packages = {
            hyperast-webapi =
              craneLib.buildPackage (WebAPIArgs // {
                cargoArtifacts = WebAPIArgsCargoArtifacts;
              });

            hyperast-gui =
              craneLib.buildTrunkPackage (GUIArgs // {
                cargoArtifacts = GUIArgsCargoArtifacts;
                wasm-bindgen-cli = pkgs.wasm-bindgen-cli.override {
                  version = "0.2.84";
                  hash = "sha256-0rK+Yx4/Jy44Fw5VwJ3tG243ZsyOIBBehYU54XP/JGk=";
                  cargoHash = "sha256-vcpxcRlW1OKoD64owFF6mkxSqmNrvY+y3Ckn5UwEQ50=";
                };
              });
          };


          devShell =
            pkgs.mkShell rec {
              buildInputs = with pkgs; [
                toolchain
                pkg-config
                nixfmt
                cmake
                trunk
                cargo-audit
              ];
              libraries = with pkgs; [
                openssl
                glibc
              ];
              LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath
                libraries;
            };
        }
      );
}
