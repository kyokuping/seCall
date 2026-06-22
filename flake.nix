{
  description = "Nix flake for secall";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
        ortEnv = {
          ORT_LIB_LOCATION = pkgs.onnxruntime;
          ORT_PREFER_DYNAMIC_LINK = "1";
          ORT_SKIP_DOWNLOAD = "1";
        };
      in
      {
        packages.default = rustPlatform.buildRustPackage ({
          pname = "secall";
          version = "0.6.3";

          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            onnxruntime
            onnxruntime.dev
            stdenv.cc.cc.lib
          ];

          cargoBuildFlags = [
            "--package"
            "secall"
            "--features"
            "web-ui"
          ];

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Searchable local wiki for AI agent conversations";
            homepage = "https://github.com/hang-in/secall";
            license = licenses.agpl3Only;
            mainProgram = "secall";
            platforms = platforms.unix;
          };
        } // ortEnv);

        devShells.default = pkgs.mkShell (ortEnv // {
          inputsFrom = [ self.packages.${system}.default ];

          packages = with pkgs; [
            cargo
            pnpm
            nodejs
            pkg-config
            rustToolchain
            rust-analyzer
          ];

          shellHook = ''
            export CARGO_BUILD_JOBS="''${CARGO_BUILD_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"
            echo "secall dev shell ready: use 'cargo build' for fast incremental builds."
          '';
        });
      }
    );
}
