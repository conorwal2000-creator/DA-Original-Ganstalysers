{
  description = "Conda FHS Environment (Fixed & Pinned)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # 1. SETUP: Define where Conda lives
      installationPath = "~/.conda";

      # 2. DOWNLOAD: Pinned version of Miniconda (Stability fix)
      # We use a specific version (py310_23.3.1) so the hash never mismatches.
      minicondaScript = pkgs.stdenv.mkDerivation rec {
        name = "miniconda-installer";
        src = pkgs.fetchurl {
          url = "https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh";
          sha256 = "aef279d6baea7f67940f16aad17ebe5f6aac97487c7c03466ff01f4819e5a651";
        };
        unpackPhase = "true";
        installPhase = "mkdir -p $out; cp $src $out/miniconda.sh";
        fixupPhase = "chmod +x $out/miniconda.sh";
      };

      # 3. INSTALLER: Wrapper to run the installer non-interactively
      condaInstaller = pkgs.runCommand "conda-install"
        { buildInputs = [ pkgs.makeWrapper minicondaScript ]; }
        ''
          mkdir -p $out/bin
          makeWrapper ${minicondaScript}/miniconda.sh $out/bin/install-miniconda \
            --add-flags "-p ${installationPath}" \
            --add-flags "-b"
        '';

      # 4. ENVIRONMENT: The FHS Bubble
      fhs = pkgs.buildFHSEnv {
        name = "conda-shell";
        targetPkgs = pkgs: (with pkgs; [
          condaInstaller
          # Standard libraries often needed by Python/Conda packages:
          xorg.libSM xorg.libICE xorg.libXrender libselinux libglvnd
          gcc git zlib glib
        ]);
        
        # 5. ACTIVATION: This script runs every time you type 'nix develop'
        profile = ''
          # Ensure the installer is on the path
          export PATH=${installationPath}/bin:$PATH

          # If conda isn't installed yet, install it automatically
          if [ ! -d ${installationPath} ]; then
            echo "⚡ Conda not found. Installing to ${installationPath}..."
            install-miniconda
          fi

          # Initialize the shell so 'conda activate' works
          if [ -f ${installationPath}/etc/profile.d/conda.sh ]; then
            source ${installationPath}/etc/profile.d/conda.sh
            echo "✅ Conda loaded. Use 'conda activate <env>'."
          fi
        '';
      };
    in
    {
      devShells.${system}.default = fhs.env;
    };
}
