{
  description = "fnox - flexible secret management tool";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-24_11.url = "github:nixos/nixpkgs/nixos-24.11";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, nixpkgs-24_11, rust-overlay, crane, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      pkgs2411 = nixpkgs-24_11.legacyPackages.${system};

      inherit (pkgs) lib;

      rust = pkgs.rust-bin.stable."1.91.1".default;
      craneLib = (crane.mkLib pkgs).overrideToolchain rust;

      unfilteredRoot = ./.; # The original, unfiltered source
      src = lib.fileset.toSource {
        root = unfilteredRoot;
        fileset = lib.fileset.unions [
          # Default files from crane (Rust and cargo files)
          (craneLib.fileset.commonCargoSources unfilteredRoot)
          # We do want the .kdl files in src/assets
          (lib.fileset.maybeMissing ./src/assets)
        ];
      };

      commonArgs = {
        inherit src;
        strictDeps = true;
        nativeBuildInputs = [ pkgs.perl pkgs.pkg-config ];
        buildInputs = [ pkgs.udev ];
      };

      # Dependencies-only derivation — only rebuilds when Cargo.lock changes
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      fnox = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
        cargoExtraArgs = "--no-default-features";
        cargoTestExtraArgs = "--lib -- --skip=providers::keychain::tests::test_keychain_set_and_get";
      });

      devShell = pkgs.mkShell {
        packages = [ rust pkgs.pkg-config pkgs.perl pkgs.systemdLibs ];
      };

      nuCheck = pkgs.runCommand "fnox-nu-integration" {
        buildInputs = [ pkgs2411.nushell fnox ];
      } ''
        ACTIVATION=$(fnox activate nu --no-hook-env)
        nu --commands "
          $ACTIVATION
          let result = (do -i { fnox } | complete)
          if \$result.exit_code == 0 {
            error make { msg: \"expected non-zero exit for no-arg fnox\" }
          }
          print \"ok: wrapper handles empty args\"
        "
        touch $out
      '';
    in {
      packages.${system} = {
        default = fnox;
        inherit fnox;
      };

      devShells.${system}.default = devShell;

      checks.${system} = {
        package = fnox;
        devShell = devShell;
        nu-integration = nuCheck;
        deps = cargoArtifacts;
      };
    };
}
