# The instructions an agent loads stay small and public-safe
# (docs/nix-rules.md "Byte gate"; accountable's docs semantics):
# - CLAUDE.md is EXACTLY the byte budget pinned in docs/claude-md-budget, so it
#   only shrinks: a smaller file lowers the budget with it, and a raise is its
#   own commit saying why. The budget itself is at most 4096.
# - docs/nix-rules.md is at most 12288 bytes.
# - Neither names a path under a person's home folder.
{ lib, nixpkgs, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  read = path: builtins.readFile (../. + "/${path}");
  size = path: lib.stringLength (read path);
  budget = lib.toInt (lib.trim (read "docs/claude-md-budget"));
  homePath = text: builtins.match ".*(/home/[a-z]|/Users/[A-Za-z]|~/).*" (lib.replaceStrings [ "\n" ] [ " " ] text) != null;

  failures =
    lib.optional (budget > 4096) "docs/claude-md-budget is ${toString budget} (max 4096)"
    ++ lib.optional (size "CLAUDE.md" != budget)
      "CLAUDE.md is ${toString (size "CLAUDE.md")} bytes, its budget ${toString budget} (they must match)"
    ++ lib.optional (size "docs/nix-rules.md" > 12288)
      "docs/nix-rules.md is ${toString (size "docs/nix-rules.md")} bytes (max 12288)"
    ++ map (p: "${p} names a path under a home folder")
      (lib.filter (p: homePath (read p)) [ "CLAUDE.md" "docs/nix-rules.md" ]);

  # Every document is public (SEC1, owner: "Scrub docs + guard"): none names a
  # person's home folder, or says where a secret lives or that one is held in
  # the clear. Matched line by line.
  docs = [ "CLAUDE.md" ] ++ map (n: "docs/${n}")
    (lib.attrNames (lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n) (builtins.readDir ../docs)));
  # Home folders are case-sensitive, and /Users/ only at the start of a path, so
  # the repo's own my/users/... paths don't match. Secret wording is
  # case-insensitive.
  homeFolder = [
    ".*/home/[a-z].*"
    "(.*[^A-Za-z0-9_./-])?/Users/[A-Za-z].*"
  ];
  secretWording = [
    ".*(plaintext|unencrypted|unrotated)[^.]{0,30}(key|secret|password).*"
    ".*[.]unencrypted.*"
  ];
  leaky = line:
    lib.any (re: builtins.match re line != null) homeFolder
    || lib.any (re: builtins.match re (lib.toLower line) != null) secretWording;
  leakyLines = path: lib.filter leaky (lib.splitString "\n" (read path));
  docFailures = lib.concatMap
    (p: map (line: "${p}: ${lib.substring 0 80 line}") (leakyLines p))
    docs;
in
{
  docs-public-safe =
    if docFailures != [ ]
    then builtins.throw ("FAIL: docs-public-safe -- " + lib.concatStringsSep " | " docFailures)
    else pkgs.runCommand "docs-public-safe" { } "echo PASS: docs-public-safe; touch $out";

  instructions-size =
    if failures != [ ]
    then builtins.throw ("FAIL: instructions-size -- " + lib.concatStringsSep "; " failures)
    else pkgs.runCommand "instructions-size" { } "echo PASS: instructions-size; touch $out";
}
