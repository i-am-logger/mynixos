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
in
{
  instructions-size =
    if failures != [ ]
    then builtins.throw ("FAIL: instructions-size -- " + lib.concatStringsSep "; " failures)
    else pkgs.runCommand "instructions-size" { } "echo PASS: instructions-size; touch $out";
}
