# The lock may hold ONE nixpkgs, plus the pins of inputs named below.
#
# Every extra nixpkgs node is a second package set: a second evaluation, a
# second closure of everything built from it, and a second answer to "which
# glibc / openssl is this host running". It arrives silently -- an input
# without `inputs.nixpkgs.follows`, or one that pins its own rev -- and nothing
# else in the check suite notices, because the extra set still evaluates.
#
# A node counts as nixpkgs when its `locked` OR its `original` names the
# NixOS/nixpkgs repository, in any fetcher shape: github, gitlab, git, tarball
# (including channels.nixos.org / releases.nixos.org), or the indirect `nixpkgs`
# registry id. `flake = false` nodes count too: an unflaked nixpkgs source is
# still a second nixpkgs. Owner and repo compare case-insensitively, because
# the root input is spelt `nixos/nixpkgs` and pinned inputs `NixOS/nixpkgs`.
#
# Paired with its opposite, like tests/secrets-store-policy.nix: a counter that
# only ever reports "too many" is indistinguishable from one that counts every
# node, and one that only reports "fine" from one that counts none.
{ lib
, nixpkgs
, system
, ...
}:

let
  pkgs = nixpkgs.legacyPackages.${system};

  # Inputs whose own nixpkgs pins are kept on purpose. A nixpkgs node is
  # excused only when EVERY edge to it starts at one of these -- directly, or
  # through a follows path whose first step is one -- so nothing else may come
  # to depend on such a pin unnoticed.
  exceptions = {
    # baud is built with a pinned nightly rustc over its own nixpkgs, and
    # upstream builds and tests that combination (baud-app/tests/install.rs
    # fails when they disagree). Keeping the pin makes the installed baud the
    # gated binary. Owner, 2026-11-15, after architect and release review.
    baud = "baud's own pin: the installed baud is the binary upstream builds and tests";
  };

  lower = lib.toLower;

  isNixpkgsRef = ref:
    let
      type = ref.type or "";
      url = lower (ref.url or "");
      urlNamesNixpkgs =
        builtins.match ".*[/:]nixos/nixpkgs(\\.git)?([/?#].*)?" url != null
        || builtins.match ".*(channels|releases)\\.nixos\\.org/.*" url != null
        || builtins.match ".*nixos\\.org/channels/.*" url != null;
    in
    if type == "github" || type == "gitlab" || type == "sourcehut" then
      lower (ref.owner or "") == "nixos" && lower (ref.repo or "") == "nixpkgs"
    else if type == "git" || type == "tarball" || type == "file" then
      urlNamesNixpkgs
    else if type == "indirect" then
      (ref.id or "") == "nixpkgs"
    else false;

  isNixpkgsNode = node:
    isNixpkgsRef (node.locked or { }) || isNixpkgsRef (node.original or { });

  # Pure analysis of a parsed flake.lock. Never throws, so the fixtures below
  # can inspect its verdict directly.
  analyse = lock:
    let
      inherit (lock) nodes;
      rootName = lock.root or "root";

      # An input value is either a node name, or a follows path walked from
      # the root, whose every step may itself be a follows.
      resolve = ref:
        if builtins.isString ref then ref
        else
          lib.foldl'
            (cur: step: resolve nodes.${cur}.inputs.${step})
            rootName
            ref;

      # node name -> the edges that land on it, as { from; input; ref; }.
      edgesTo = target:
        lib.concatLists (lib.mapAttrsToList
          (from: node:
            lib.concatLists (lib.mapAttrsToList
              (input: ref: lib.optional (resolve ref == target) { inherit from input ref; })
              (node.inputs or { })))
          nodes);

      showEdge = e:
        if builtins.isString e.ref
        then "${e.from}.${e.input}"
        else "${e.from}.${e.input} (follows ${lib.concatStringsSep "/" e.ref})";

      # An excepted input's own subtree: the input, and every node reached from
      # it through direct (non-follows) edges -- baud's rust-overlay. Who
      # holds an edge decides, not where it points: an unrelated input that
      # follows baud/nixpkgs is NOT excused.
      owned = lib.foldl'
        (seen: _:
          lib.unique (seen ++ lib.concatMap
            (n: lib.filter builtins.isString (lib.attrValues (nodes.${n}.inputs or { })))
            seen))
        (lib.filter (n: nodes ? ${n}) (lib.attrNames exceptions))
        (lib.attrNames nodes);

      excepted = e: lib.elem e.from owned;

      found = lib.attrNames (lib.filterAttrs (_: isNixpkgsNode) nodes);

      # The one that is allowed: whatever the root's own `nixpkgs` input is.
      rootNixpkgs =
        let r = nodes.${rootName}.inputs.nixpkgs or null;
        in if r == null then null else resolve r;

      excused = lib.filter
        (n: n != rootNixpkgs && edgesTo n != [ ] && lib.all excepted (edgesTo n))
        found;

      extra = lib.filter (n: n != rootNixpkgs && !(lib.elem n excused)) found;

      describe = name:
        let
          node = nodes.${name};
          l = node.locked or { };
          where =
            if l ? owner then "${l.type}:${l.owner}/${l.repo}"
            else l.url or (l.type or "?");
          pin = if l ? rev then " @ ${builtins.substring 0 8 l.rev}" else "";
          from = map showEdge (edgesTo name);
        in
        "  ${name}  ${where}${pin}\n    referenced by: "
        + (if from == [ ] then "(nothing -- stale lock entry)"
        else lib.concatStringsSep ", " from);
    in
    {
      inherit found extra excused rootNixpkgs;
      ok = extra == [ ];
      message =
        "FAIL: single-nixpkgs -- flake.lock holds ${toString (builtins.length extra)} "
        + "nixpkgs node(s) beyond root.nixpkgs (${toString rootNixpkgs}) and the pins of "
        + "${lib.concatStringsSep ", " (lib.attrNames exceptions)}.\n"
        + "Extra nodes, and who brings them in:\n"
        + lib.concatMapStringsSep "\n" describe extra
        + "\nFix: add `inputs.<x>.inputs.nixpkgs.follows = \"nixpkgs\";` for each referrer above.";
    };

  # ---- fixtures: the counter must be able to say both "yes" and "no" ----

  gh = owner: rev: {
    locked = { type = "github"; inherit owner rev; repo = "nixpkgs"; };
    original = { type = "github"; inherit owner; repo = "nixpkgs"; ref = "nixos-unstable"; };
  };

  dep = name: inputs: {
    locked = { type = "github"; owner = "x"; repo = name; rev = "1"; };
    inherit inputs;
  };

  oneNode = {
    root = "root";
    version = 7;
    nodes = {
      root.inputs = { nixpkgs = "nixpkgs"; dep = "dep"; };
      nixpkgs = gh "nixos" "aaaaaaaa";
      dep = dep "dep" { nixpkgs = [ "nixpkgs" ]; };
    };
  };

  # Several shapes, none of them excepted: an input with its own nixpkgs, an
  # unflaked tarball and a git URL, all of which must count.
  manyNodes = {
    root = "root";
    version = 7;
    nodes = {
      root.inputs = { nixpkgs = "nixpkgs_2"; dep = "dep"; };
      nixpkgs_2 = gh "nixos" "aaaaaaaa";
      nixpkgs = gh "NixOS" "bbbbbbbb";
      nixpkgs-tar.locked = { type = "tarball"; url = "https://releases.nixos.org/nixos/unstable/x/nixexprs.tar.xz"; };
      nixpkgs-git.locked = { type = "git"; url = "https://github.com/NixOS/nixpkgs.git"; rev = "c"; };
      dep = dep "dep" {
        nixpkgs = "nixpkgs";
        tar = "nixpkgs-tar";
        git = "nixpkgs-git";
        also = [ "dep" "nixpkgs" ];
      };
    };
  };

  # The shape baud has: its own nixpkgs, followed by its rust-overlay. With
  # `withOther`, an unrelated root input follows baud's pin as well.
  bauds = withOther: {
    root = "root";
    version = 7;
    nodes = {
      root.inputs = { nixpkgs = "nixpkgs_2"; baud = "baud"; }
        // lib.optionalAttrs withOther { other = "other"; };
      nixpkgs_2 = gh "nixos" "aaaaaaaa";
      nixpkgs = gh "NixOS" "bbbbbbbb";
      baud = dep "baud" { nixpkgs = "nixpkgs"; rust-overlay = "rust-overlay"; };
      rust-overlay = dep "rust-overlay" { nixpkgs = [ "baud" "nixpkgs" ]; };
    } // lib.optionalAttrs withOther {
      other = dep "other" { nixpkgs = [ "baud" "nixpkgs" ]; };
    };
  };

  fixtureClauses = {
    "one node passes" = (analyse oneNode).ok;
    "follows is not a node" = (analyse oneNode).found == [ "nixpkgs" ];
    "four nodes fail" = !(analyse manyNodes).ok;
    "every shape counts" =
      lib.sort lib.lessThan (analyse manyNodes).found
      == [ "nixpkgs" "nixpkgs-git" "nixpkgs-tar" "nixpkgs_2" ];
    "root's own is never extra" = !(lib.elem "nixpkgs_2" (analyse manyNodes).extra);
    "referrers are named" =
      lib.hasInfix "dep.nixpkgs" (analyse manyNodes).message
      && lib.hasInfix "dep.also (follows dep/nixpkgs)" (analyse manyNodes).message;
    "baud's own pin is excused" =
      (analyse (bauds false)).ok && (analyse (bauds false)).excused == [ "nixpkgs" ];
    "anything else reaching baud's pin fails" =
      !(analyse (bauds true)).ok
      && lib.hasInfix "other.nixpkgs (follows baud/nixpkgs)" (analyse (bauds true)).message;
  };

  fixturesFailed = lib.attrNames (lib.filterAttrs (_: ok: !ok) fixtureClauses);

  real = analyse (builtins.fromJSON (builtins.readFile ../flake.lock));

  pass = name: pkgs.runCommand name { } ''
    echo "PASS: ${name}"
    touch $out
  '';
in
{
  single-nixpkgs-fixtures =
    if fixturesFailed != [ ]
    then builtins.throw "FAIL: single-nixpkgs-fixtures -- did not hold: ${lib.concatStringsSep ", " fixturesFailed}"
    else pass "single-nixpkgs-fixtures";

  single-nixpkgs =
    if !real.ok then builtins.throw real.message
    else pass "single-nixpkgs";
}
