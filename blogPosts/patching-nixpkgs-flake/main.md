# Patching nixpkgs in a flake

Suppose there is a patch upstream that depends on a specific version of Python, e.g., `3.13.8`, but the patch trails the current tip such that the Python version on our `inputs.nixpkgs` is `3.13.9`.

In this case, we have two options:

1. meticilously override each dependency of the patched package, and every app that depends on it, to use `3.18.8` (in my case, it would have been `trezor` and `trezor-agent`, but one can image much bigger closure)
2. lock our whole nixpkgs to `3.13.8` and cause a huge recompile due to cache misses

What we can do instead is to apply a patch on the upstream `inputs.nixpkgs` to change the source code such that we automatically gain steps we would do in 1 (under `perSystem` closure):

```nix
let
  nixpkgs-patched = import
    ((import inputs.nixpkgs { inherit system; }).applyPatches {
      name = "nixpkgs-pr-455630";
      src = inputs.nixpkgs;
      patches = [ ./packages/trezor/455630.patch ];
    })
    {
      inherit system;
      config.permittedInsecurePackages = [ "python3.13-ecdsa-0.19.1" ];
    };
in
{
  # packages, devShells, etc.
};
```

Here, the patch is a git changeset of the proposed pull-request.

Finally, we _may_ apply configuration parameters that affect only the patched package closure, as done here with the `permittedInsecurePackages`.
This step is only necessary if the patched package is marked as insecure, which is often the reason one would employ this strategy.

Unfortunately, this closure must be duplicated on both our patched nixpkgs, as well as our upstream nixpkgs :

```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  overlays = [
    self.overlays.default
  ];
  config = {
    permittedInsecurePackages = [ "python3.13-ecdsa-0.19.1" ];
  };
};
```

and:

```nix
nix = {
  # ...
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "python3.13-ecdsa-0.19.1"
    ];
  };
```

At this point, running `nix flake check` should succeed.

We can then continue to override the derivations under `perSystem.packages`:

```nix
"trezorctl" = nixpkgs-patched.trezorctl;
"trezor-agent" =
  let
    trezor-old-relaxed = pkgs.python3Packages.trezor.overridePythonAttrs (_old: {
      pythonRelaxDeps = [ "click" ];
    });
  in
  pkgs.python3Packages.trezor-agent.override {
    trezor = trezor-old-relaxed;
  };
```

This means that `trezorctl` is built with the Python version of the upstream `inputs.nixpkgs`, but with the corresponding diff from upstream.
Further, in the `trezor-agent` closure we do some application specific surgery which got implemented in a yet-unrelated version.

Overall, this keeps our configuration _relatively_ tidy and clear regarding what fixes are related to the affected patchset.

To cherry-pick patches, we override the package we need (which, in this case, the whole `python313` package set due to Python insanities) with the patched version:

```nix
"python313" = pkgs.python313.override {
  packageOverrides = _: _: {
    inherit (nixpkgs-patched.python313Packages) trezor;
  };
};
```

To apply this override globally, we add it to our overlays (flake.parts pattern):

```nix
overlayAttrs = {
  inherit (config.packages) python313;
};
```

This overlay gets applied to our nixpkgs with:

```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  overlays = [ self.overlays.default ];
};
 ```

Now, the surgery is done.
Once the changes are upstreamed, you will be met with an error message saying the patch failed to apply after running `nix flake update nixpkgs`.

For more, see:

- [https://ertt.ca/nix/patch-nixpkgs/](https://ertt.ca/nix/patch-nixpkgs/)
- [https://juuso.dev/blogPosts/modular-neovim/modular-neovim-with-nix.html](https://juuso.dev/blogPosts/modular-neovim/modular-neovim-with-nix.html)

Finally, it would be great if this would also apply to `nixosModules`, but that shall not be the case for some time: [https://github.com/NixOS/nix/pull/13225](https://github.com/NixOS/nix/pull/13225)
