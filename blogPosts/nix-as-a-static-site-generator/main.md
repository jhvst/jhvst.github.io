# |title|

_|description|_

![Hacker News comment prompting me to this](./img/hn.avif)

This is a commentary to a blog post _[`make` as a Static Site Generator](https://www.karl.berlin/static-site.html)_ and a HN comment which said the following:

> A problem with this approach is that deleting a file from source/ does not delete it from build/.
> In my own projects, simply rebuilding the whole site is fast enough, so I opt to remove the whole build folder before a rebuild:
> https://github.com/jez/jez.github.io/blob/source/Makefile#L1...
> This defeats a big part of why you’d want a build system in the first place (incremental builds), but at least if you know the page you want to regenerate you can still `make` that file directly.
> If there’s a common workaround for this pattern in makefiles I’d love to learn it.

I use Nix to generate the pages on this blog.
It has some interesting upsides: I have incremental builds while ensuring that the build folder is always up to date.
I host the source code at [GitHub](https://github.com/jhvst/jhvst.github.io).

When I write a new blog post, I make a directory first at `blogPosts` folder.
Then, I use Nix templates to generate the basic config: `nix flake init -t ../../` which generates a `flake.nix` file.
I then change the `title`, `description`, `pubDate`, and `name` entry on the `flake.nix`.
Then, to make these new files appear for Nix, I run `git add flake.nix`.

I then start writing Markdown: `nix run ../..#neovim -- main.md`.
This pulls in some additional packages for writing my Neovim configuration as described in my blog post _[Modular Neovim with Nix](https://juuso.dev/blogPosts/modular-neovim/modular-neovim-with-nix.html)_.

When done, I run `git add main.md` followed by `nix build`.
This creates a lockfile `flake.lock` which pins the dependencies like template files for me.
This is useful so that if I update my template file later in a breaking way, it does not break previously generated entries.
In other words, each page is ensured to work and look the same even if I update CSS or HTML.
The actual build script is a bash script like this:

```nix
packages.default = pkgs.stdenv.mkDerivation rec {

  title = "Nix as a Static Site Generator";
  description = "A pathway incremental builds and reproducability";
  pubDate = "10 Sep 2023 16:45:00 GMT";

  name = "";
  src = ./.;
  buildInputs = with pkgs; [
    inputs'.barbell.packages.barbell
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
    cp -r ${inputs'.web-components.packages.default}/html/* ./html
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
    barbell html/template_article.html > $out/$(slugify ${title}).html
    js-beautify -f $out/$(slugify ${title}).html -r
  '';

  doCheck = true;
  checkPhase = ''
    vnu $out/$(slugify ${title}).html
  '';
};
```

So what this does is as follows:

1. in `buildInputs` I pull packages that the bash script needs
2. `buildPhase` includes the actual commands. I first create bunch of folders, generate the font file for `code` blocks, then use `pandoc` to generate a HTML page
3. I then create files that the template file uses using [a template engine I wrote in BQN](https://juuso.dev/blogPosts/barbell/barbell.html) called `barbell` -- what this does is that it creates variables that get included in the HTML template where blocks such as `|variable|` exist
4. then the `barbell` command is used to create an article page: `barbell main.html > article.bar`
5. `barbell` is used recursively to also include blocks in the html template: `barbell html/template_article.html > $out/$(slugify ${title}.html)`
6. file is beutified in-place: `js-beautify -f $out/$(slugify ${title}).html -r`
7. the `checkPhase` runs a sanity check using W3C validator `vnu $out/$(slugify ${title}).html` -- this is useful to check that the page was generated OK without actually looking at the file
8. I can now preview the page in the build folder: `open result`

When I'm done, I run `git add flake.lock` and I push this to GitHub.
This does not include the page on my blog yet, but it creates an URL that I can import.
The URL looks like: `github:jhvst/jhvst.github.io?dir=blogPosts/${title}`.

I then update my main flake which generates my blog, which is found from the project root folder.
This works as follows:

1. run `nix flake update` so that the new dir folder resolves
2. add a new import: suppose the name of the entry is foo, then I add `foo.url = "github:jhvst/jhvst.github.io?dir=blogPosts/foo`
3. in the `buildPhase` of my root flake, I add the following lines: `mkdir -p $out/blogPosts/foo` and `cp -r ${inputs.foo.outputs.packages.${system}.default}/* $out/blogPosts/foo` -- this copies the build assets to an URL that I want to have the page
4. I update the `rss.xml` file if I want it to appear in my RSS feed
5. `git commit` and `git push` will trigger a GitHub Action which builds my site, and pushes the resulting build folder to GitHub pages

Done.
To see the diffs see: [1)](https://github.com/jhvst/jhvst.github.io/commit/0d1f97099749b98c84ed48f4def454ba850d3672) and [2)](https://github.com/jhvst/jhvst.github.io/commit/977e22ccf238627eea85d6f238ca251bba2a1724).

Somewhat of a downside is that if I want to update my blog post, I always need two git pushes.
However, overall I'm quite happy with my setup and don't see why to go back anymore.

