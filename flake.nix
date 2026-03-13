{
  description = "Construct development shell from requirements.txt";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";

  outputs =
    { nixpkgs, pyproject-nix, ... }:
    let
      project = pyproject-nix.lib.project.loadRequirementsTxt { projectRoot = ./.; };

      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      
      python = pkgs.python3.override {
        packageOverrides = final: prev: {
          missingno = prev.buildPythonPackage rec {
            pname = "missingno";
            version = "0.5.2";
            pyproject = true;
            src = prev.fetchPypi {
              inherit pname version;
              sha256 = "4a4baa9ca9f9e4e0d9402455df26b656632e94b99e87fa64c0cdbbbc722837ac";
            };
            build-system = [ final.setuptools ];
            dependencies = with final; [ numpy matplotlib scipy seaborn ];
            doCheck = false;
          };
        };
      };

      pythonEnv =
        assert project.validators.validateVersionConstraints { inherit python; } == { };
        (
          python.withPackages (project.renderers.withPackages { inherit python; })
        );

    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell { packages = [ pythonEnv ]; };
    };
}
