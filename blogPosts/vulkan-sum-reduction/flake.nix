{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.05";
    web-components.url = "github:jhvst/jhvst.github.io?dir=packages/web-components";
    barbell.url = "github:jhvst/barbell";
  };

  outputs = { self, nixpkgs, ... } @inputs:

    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });
    in

    {
      packages = forEachSupportedSystem ({ pkgs, system }: {
        default = pkgs.stdenv.mkDerivation rec {

          title = "Vulkan sum reduction";
          description = "We describe how we can do sum reduction using SPIR-V subgroups up to vector length of 4096. With SPIR-V, we are able to run this program on GPUs of different manufacturers using the Vulkan GPU API. As Vulkan is supported by Nvidia, AMD, and, e.g., Apple ARM among others, this allows us to build cross-compatible array operations similar to CUDA.";
          pubDate = "23 Mar 2022 16:30:00 GMT";

          name = "vksum";
          src = ./.;
          buildInputs = with pkgs; [
            inputs.barbell.packages.${system}.barbell
            nodePackages.js-beautify
            pandoc
            python311Packages.python-slugify
            validator-nu
            woff2
          ];
          phases = [ "unpackPhase" "buildPhase" "checkPhase" ];
          buildPhase = ''
            mkdir -p $out/css
            mkdir -p $out/img
            mkdir html
            cp -r ${inputs.web-components.packages.${system}.default}/html/* ./html
            cp ${pkgs.ibm-plex}/share/fonts/opentype/IBMPlexMono-Regular.otf .
            cp -r img/* $out/img
            woff2_compress IBMPlexMono-Regular.otf
            cp IBMPlexMono-Regular.woff2 $out/
            pandoc main.md --katex -o main.html

            echo "${title}" > title.bar
            echo "${description}" > description.bar
            echo "${pubDate}" > pubDate.bar
            echo "${name}" > name.bar
            slugify ${title} > slug.bar
            date -d "${pubDate}" -Iminutes > datetime.bar
            cat main.md | wc -w > wordCount.bar

            barbell main.html > article.bar
            barbell ./html/template_article.html > $out/$(slugify ${title}).html
            js-beautify -f $out/$(slugify ${title}).html -r
          '';

          doCheck = true;
          checkPhase = ''
            vnu $out/$(slugify ${title}).html
          '';
        };
      });
    };
}
