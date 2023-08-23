{
  description = "Audiobookshelf flake";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    flake-parts.url = "github:hercules-ci/flake-parts";

    alejandra.url = "https://flakehub.com/f/kamadorueda/alejandra/3.0.0.tar.gz";
    nixd.url = "https://flakehub.com/f/nix-community/nixd/1.2.2.tar.gz";

    audiobookshelf = {
      url = "github:advplyr/audiobookshelf/v2.3.3";
      flake = false;
    };
    tone.url = "https://flakehub.com/f/ajaxbits/tone/0.1.5.tar.gz";
  };

  outputs = {
    self,
    nixpkgs,
    nixd,
    audiobookshelf,
    tone,
    flake-parts,
    alejandra,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: let
        pname = "audiobookshelf";
        version = "v2.3.3";
        description = "Self-hosted audiobook server for managing and playing audiobooks";

        client = pkgs.buildNpmPackage {
          pname = "${pname}-client";
          inherit version;

          src = pkgs.runCommand "cp-source" {} ''
            cp -r ${audiobookshelf}/client $out
          '';

          NODE_OPTIONS = "--openssl-legacy-provider";

          npmBuildScript = "generate";
          npmDepsHash = "sha256-s3CwGFK87podBJwAqh7JoMA28vnmf77iexrAbbwZlFk=";
        };

        server = pkgs.buildNpmPackage {
          inherit pname version description;
          src = inputs.audiobookshelf;

          buildInputs = [pkgs.util-linux];
          nativeBuildInputs = [pkgs.python3];

          dontNpmBuild = true;
          npmInstallFlags = ["--only-production"];
          npmDepsHash = "sha256-gueSlQh4tRTjIWvpNG2cj1np/zUGbjsnv3fA2owtiQY=";

          installPhase = ''
            mkdir -p $out/opt/client
            cp -r index.js server package* node_modules $out/opt/
            cp -r ${client}/lib/node_modules/${pname}-client/dist $out/opt/client/dist
            mkdir $out/bin

            echo '${wrapper}' > $out/bin/${pname}
            echo "  exec ${pkgs.nodejs_18}/bin/node $out/opt/index.js" >> $out/bin/${pname}

            chmod +x $out/bin/${pname}
          '';
        };

        wrapper = import ./wrapper.nix {
          stdenv = pkgs.stdenv;
          ffmpeg-full = pkgs.ffmpeg-full;
          tone = inputs.tone.packages.${system}.default;
        };
      in {
        packages.default = pkgs.buildNpmPackage {
          inherit pname version;
          src = inputs.audiobookshelf;

          buildInputs = [pkgs.util-linux];
          nativeBuildInputs = [pkgs.python3];

          dontNpmBuild = true;
          npmInstallFlags = ["--only-production"];
          npmDepsHash = "sha256-gueSlQh4tRTjIWvpNG2cj1np/zUGbjsnv3fA2owtiQY=";

          installPhase = ''
            mkdir -p $out/opt/client
            cp -r index.js server package* node_modules $out/opt/
            cp -r ${client}/lib/node_modules/${pname}-client/dist $out/opt/client/dist
            mkdir $out/bin

            echo '${wrapper}' > $out/bin/${pname}
            echo "  exec ${pkgs.nodejs_18}/bin/node $out/opt/index.js" >> $out/bin/${pname}

            chmod +x $out/bin/${pname}
          '';
        };

        formatter = inputs.alejandra.packages.${system}.default;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_18
            pkgs.ffmpeg-full
            inputs.tone.packages.${system}.default
            inputs.nixd.packages.${system}.default
            inputs.alejandra.packages.${system}.default
          ];
        };
      };
    };
}
