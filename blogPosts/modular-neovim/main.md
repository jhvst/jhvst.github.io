# |title|

_|description|_

This blog post explains how I modularized my Neovim configuration on a per-project using Nix and [devenv](https://devenv.sh).
The initial motivation was to reduce the size of my Neovim installation.
The idea was to have a smaller _core_ installation with essential settings and packages.
This would allow adding Neovim to all my servers and development machines without pulling in a lot of dependencies.

The expansions would work using Nix integration.
In each project, say in Rust, nodejs, or BQN, I would define project-specific additional packages and extensions in the project's `flake.nix` file.
This keeps my core installation small and tidy while allowing Neovim to expand "just in time" when needed.
Thanks to `direnv`, the project-specific tools unload from my path when I leave the project folder.

The key approach to this was the [nixvim](https://github.com/nix-community/nixvim) project.
It allows Neovim to be configured using Nix, by packaging a custom version of Neovim.
Doing this requires advanced familiarity with Nix, an excellent way to introduce these concepts.

## The shell environment

In the Nix ecosystem, various projects leverage per-folder environments to pin dependencies.
Examples of this are [direnv](https://direnv.net) and [devenv](https://devenv.sh).
The motivation is to establish something akin to [Fig](https://fig.io), which recently [published](https://fig.io/blog/post/fig-joins-aws) that it was being acquired by AWS.

The extrapolation behind the rationale of the acquisition works somewhat as follows: when AWS can hook into the developer's shell environment, they can provide additional value by making it easy to consume and conjure new AWS services on the go (... and occasionally forget about them).
In the shell environment, AWS has additional _context_ of what the developer is working on, which allows pinpointing new cloud subscriptions directly onto that project by essentially using the folder path as an identifier.

In the Nix world, we do the same thing using `direnv` and `devenv` by leveraging Nix abstractions.
The basic idea is that you have a configuration file in the project root folder to define `packages` that are fetched using Nix from the [package repository](https://search.nixos.org/packages).
This file integrates with direnv's `.envrc` file, which your shell scans on each `cd` command.
Nix will install those packages transiently into your path if the file is present, using a version defined in a `flake.lock` lock file.
This way, Nix Flakes allows different versions of the same package to coexist within an organization's repositories.
This aids in the reproducibility of the developer environment as the lock file determines which version of some software is needed --  avoiding the "works on my machine" tantrum.

## Modularizing Neovim with NixVim

So, now that the `.envrc` file hooks into the shell and loads the packages defined with `devenv` using Nix Flakes' `flakes.lock` lock file to determine the correct version, how do we continue with Neovim?

Here, the NixVim project allows us to define the required packages as such:

```nix
{
  programs.nixvim = {
    enable = true;

    colorschemes.gruvbox.enable = true;
    plugins.lightline.enable = true;
  };
}
```

This will effectively generate the required Lua and VimScript files to the user's configuration folder, install Neovim, and add it to your shell path.
However, to extend this file dynamically, we have to be able to read the declaration that was used to create them.

The solution to extend the configuration is called `nixosModules`, one of the interfaces Nix Flakes produces.
Nix Flakes is an interface that produces various methods in the so-called [output schema](https://nixos.wiki/wiki/Flakes).
These methods have various additional tooling hooked up to them.
For example, if you declare a new package using the `packages."<system>"."<name>" = derivation;` method, where `"<system>"` is your system architecture like `aarch64-darwin` and `"<name>"` is the package name like `neovim`, then you can use a command `nix build .#neovim` to produce the output of the packaging script.
The build command semantics also hide an abstraction: the `.` part is the location of the Nix Flakes interface to read.
When it is `.`, it means the current directory, but it could also be `nixpkgs`, meaning the canonical package repository, or alternatively any local or remote git path.
For example, running `nix build nixpkgs#cowsay` would build the `cowsay` program.

In this sense, the Nix commands are a _view_ of some Nix Flakes repository.
Nix Flakes also allows any arbitrary entry points to be defined.
For example, if I would declare a new method called `user` and define it as `user = "juuso"`, I could evaluate this value by running `nix eval --raw github:jhvst/nix-config#user` to get the output `juuso` to my shell.

For options such as the Neovim configuration, it is more idiomatic to use the `nixosModules` method.
This is because here, programs can assume it can find the corresponding schema under it, which is of the form `{ config }: { options = {}; config = {}; };`.

Luckily, the NixVim authors have thought about this _composability_, for which they have implemented a method called `makeNixvimWithModule`.
This method will consume a `nixosModule` as its configuration.
We can thus do the following:

```nix
packages.neovim = nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;
  module = {
    imports = [
      inputs.juuso.outputs.nixosModules.neovim
    ];
    plugins.lightline.enable = true;
  };
};
```

Which will build us a Neovim configuration by fetching the view `nixosModules.neovim` from our input `github:jhvst/nix-config`.
Because this is now a package declaration, we can run `nix run .#neovim`, which will fetch our declaration from git, create a lock file, and then add the `lightline` plugin.

This works with some caveats.

## Filling the gaps with overlays

The approach above is fine _if_ the configuration does not have user-defined packages or modifications compared to the main nixpkgs repository.
However, I use the `himalaya-vim` package, which has a build error on macOS.
I have patched the package to include macOS-specific tools but must convey the patched version downstream onto the view.

The `nixosModules` view has no direct way to be aware of these overwrites, so we need overlays to propagate changes.
Overlays allow us to add or rewrite packages to nixpkgs without upstreaming the changes.
Adding this to integrate with `nixosModules` requires redefining the `pkgs` repository to be a view of nixpkgs defined by our repository.

This is where it becomes a tad complicated.
First, we have to rewrite the nixpkgs as follows:

```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  overlays = [
    inputs.juuso.overlays.default
  ];
  config = { };
};
```

The overlay is now pointing to our repository, where we have to produce an overlay:

```nix
overlayAttrs = {
  inherit (config.packages) himalaya;
};
```

The expression says to create an overlay of our packages and include the `himalaya` package. Now, in our packages definition, we can do the following:

```nix
packages = {
  "himalaya" = pkgs.himalaya.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.darwin.Security ];
  });
};
```

This means we take the `himalaya` package from the canonical nixpkgs repository but then add `pkgs.darwin.Security` to the `darwin` platform. In this case, it fixes the build build problem which exists upstream.

And this works! We can now fetch our base Neovim configuration while preserving any derivations of the upstream by providing our view of the canonical package repository.

## Putting it to together

Now, we can try it out.
I used my project called `barbell` for starters. This is a good candidate because it is written in a language called [BQN](https://mlochbaum.github.io/BQN/), which does not have its editor packages in the main nixpkgs repository.

What happens behind the scenes is that when we `cd` into the `barbell` repository, my shell `fish` finds the `.envrc` file and then uses `devenv` to find the packages that have to be installed.
Nix builds those packages and adds them to our path.
The devenv packages can also be configured in the `flakes.nix` file.

The definition with all the required changes looks as so:

```nix
bqnlsp.url = "sourcehut:~detegr/bqnlsp";
devenv.url = "github:cachix/devenv";
juuso.url = "github:jhvst/nix-config";

...

imports = [
  inputs.devenv.flakeModule
];

...

_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  overlays = [
    inputs.juuso.overlays.default
  ];
  config = { };
};

...

packages.neovim = nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;
  module = {
    imports = [
      inputs.juuso.outputs.nixosModules.neovim
    ];
    extraPackages = with pkgs; [
      cbqn # bqnlsp assumes cbqn in path
    ];
    extraConfigVim = ''
      au BufRead,BufNewFile *.bqn setf bqn
      au BufRead,BufNewFile * if getline(1) =~ '^#!.*bqn$' | setf bqn | endif
    '';
    plugins.lsp = {
      enable = true;
      preConfig = ''
        local configs = require('lspconfig.configs')
        local util = require('lspconfig.util')

        if not configs.bqnlsp then
          configs.bqnlsp = {
            default_config = {
              cmd = { 'bqnlsp' },
              cmd_env = {},
              filetypes = { 'bqn' },
              root_dir = util.find_git_ancestor,
              single_file_support = false,
            },
            docs = {
              description = [[ BQN Language Server ]],
              default_config = {
                root_dir = [[util.find_git_ancestor]],
              },
            },
          }
        end
      '';
    };
    extraPlugins = [
      inputs.bqnlsp.packages.${system}.lsp
      (pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "bqn-vim";
        version = pkgs.mbqn.version;
        src = pkgs.mbqn.src;
        sourceRoot = "source/editors/vim";
        meta.homepage = "https://github.com/mlochbaum/BQN/editors/vim";
      })
      (pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "nvim-bqn";
        version = "unstable";
        src = builtins.fetchGit {
          url = "https://git.sr.ht/~detegr/nvim-bqn";
          rev = "bbe1a8d93f490d79e55dd0ddf22dc1c43e710eb3";
        };
        meta.homepage = "https://git.sr.ht/~detegr/nvim-bqn/";
      })
    ];
  };
};

...

devenv.shells.default = {
  packages = [
    config.packages.neovim
  ];
};
```

1. Nix pulls the remotes from git for LSP of BQN, devenv, and my configuration.
2. It makes a lock file for each independently.
3. devenv hooks with Nix.
4. we define our overlay to get the additional packages our configuration requires.
5. we define to build a new version of Neovim using our base config.
6. we add specific packages and configurations to [BQN](https://mlochbaum.github.io/BQN/).
7. we define that the patched derivation of Neovim should be added to the shell path using `devenv`.

We can now run `nix run .#neovim -- example.bqn`, which will open `example.bqn` in Neovim (arguments to the program fetched via `nix run` have to be separated with double dashes) with all project-specific addons installed!

This works even without cloning the repository: `nix run github:jhvst/barbell#neovim -- example.bqn`.

Nifty!

## One more thing

Now, we have a transient version of Neovim that uses our base configuration in our projects.
What about installing the base configuration as our default one?

In my `nix-config` repository, I can define the base configuration of Neovim to be added to my user path using home-manager:

```nix
home-manager.users.juuso.programs.nixvim = let neovim = (import ../../../nixosModules/neovim) { inherit config pkgs; }; in with neovim.config; {
  inherit colorschemes extraConfigVim extraConfigLua extraPackages plugins extraPlugins;
  enable = true;
  viAlias = true;
  vimAlias = true;
};
```

This will read the local nixosModule while inheriting (bringing variables into the scope) the necessary fields into our local NixVim configuration block.

However, we still need help adding overlays to our local configuration.
This is arguably a bit simpler: wherever we define the Nix configuration for our computer, we also have to add a nixpkgs overlays definition:

```nix
nixpkgs.overlays = [
  outputs.overlays.default
];
```

This now rewrites the packages even in our own configuration to use the overlays we defined for `himalaya`.

Done!

## Where is the source?

The code for our `nixosModule` can be found [here](https://github.com/jhvst/nix-config/blob/main/nixosModules/neovim/default.nix).
The definition for the overlays is [here](https://github.com/jhvst/nix-config/blob/main/flake.nix).
Our package overlay is [here](https://github.com/jhvst/nix-config/blob/main/nix-settings.nix#L59). The BQN barbell configuration in its completeness is [here](https://github.com/jhvst/barbell/blob/main/flake.nix).

## The takeaway

As a result, we have successfully modularized our Neovim configuration on a per-project basis.
This keeps our base configuration slim while allowing it to be extended declaratively.
We can update our configuration at will, but because every remote project uses its own lock file, those are pinned to the moment of definition.
If we need to update the remote definitions in `barbell` to reflect changes in our upstream, we can run `nix flake update`.

Now, anyone with Nix can copy and launch my Neovim configuration using `nix run github:jhvst/nix-config#neovim`.
This is possible because Nix Flakes works as a view to a composition of git-managed resources.
For example, programming language communities could provide their own derivations of editors.
This could help new users with the learning curve.

How long did it take to get working? One day. I have used Nix in production at my company for over a year now, though (see: [homestaking-infra](https://github.com/ponkila/homestaking-infra).
Nevertheless, this opens new ways to think about developer environments.
Reflecting on Fig, we could also expand the `devenv` integration with SSH servers, CI, or environment variables.
But with Nix, we are not tied to a single service provider like AWS for those resources and integrations.

To give this a try, make sure you have Nix installed and run `nix run github:jhvst/barbell#neovim -- example.bqn`.
