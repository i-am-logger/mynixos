# my/hardware/display/layout.nix, driven directly: no NixOS evaluation, so each
# case is the arithmetic and nothing else. The module-level wiring (assertions,
# the Hyprland rules) is covered in tests/module-eval.nix.
{ lib
, nixpkgs
, system
, ...
}:

let
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (import ../my/hardware/display/layout.nix { inherit lib; }) resolve;

  uhd = { width = 3840; height = 2160; refresh = 239.99; };
  qhd = { width = 2560; height = 1440; refresh = 60; };

  positions = r: lib.mapAttrs (_: e: e.position) r.entries;

  # Each case: the resolver's answer, and what it must be. A failure prints both.
  cases = {
    # 3840x2160 at 1.5 is 2560x1440 logical; a 2560x1440 panel turned 90° is
    # 1440x2560. Centred to the right of the first, it starts 560 px higher,
    # and normalising moves the first one down instead.
    right-of-scaled-and-rotated = {
      got = positions (resolve {
        monitors = { main.mode = uhd; side.mode = qhd; };
        layout = {
          main.scale = 1.5;
          side = { position = { rightOf = "main"; align = "center"; }; transform.rotation = 90; };
        };
      });
      want = { main = { x = 0; y = 560; }; side = { x = 2560; y = 0; }; };
    };

    sizes-are-logical = {
      got = lib.mapAttrs (_: e: e.size)
        (resolve {
          monitors = { main.mode = uhd; side.mode = qhd; };
          layout = { main.scale = 1.5; side.transform.rotation = 270; };
        }).entries;
      want = { main = { width = 2560; height = 1440; }; side = { width = 1440; height = 2560; }; };
    };

    left-of-normalises = {
      got = positions (resolve {
        monitors = { main.mode = uhd; side.mode = qhd; };
        layout.side.position.leftOf = "main";
      });
      want = { main = { x = 2560; y = 0; }; side = { x = 0; y = 0; }; };
    };

    below-aligned-end = {
      got = positions (resolve {
        monitors = { main.mode = uhd; laptop.mode = qhd; };
        layout.laptop.position = { below = "main"; align = "end"; };
      });
      want = { main = { x = 0; y = 0; }; laptop = { x = 1280; y = 2160; }; };
    };

    above-centred = {
      got = positions (resolve {
        monitors = { main.mode = uhd; top.mode = qhd; };
        layout.top.position = { above = "main"; align = "center"; };
      });
      want = { main = { x = 0; y = 1440; }; top = { x = 640; y = 0; }; };
    };

    # Absolute coordinates pass through; an unreferenced "auto" stays "auto";
    # a mirror has no position of its own, and needs no mode.
    absolute-auto-mirror = {
      got = positions (resolve {
        monitors = { a.mode = uhd; b.mode = "highres"; c.mode = null; };
        layout = { a.position = { x = 0; y = 0; }; c.mirror = "a"; };
      });
      want = { a = { x = 0; y = 0; }; b = "auto"; c = "auto"; };
    };

    # A disabled monitor renders only `disabled`, so its scale is never applied
    # and a fractional one must not be refused.
    disabled-fractional-scale-is-fine = {
      got = (resolve {
        monitors.a.mode = qhd;
        layout.a = { enable = false; scale = 1.5; };
      }).errors;
      want = [ ];
    };

    clean-layout-has-no-errors = {
      got = (resolve {
        monitors = { main.mode = uhd; side.mode = qhd; };
        layout = { main.scale = 1.5; side.position.rightOf = "main"; };
      }).errors;
      want = [ ];
    };
  };

  # Each refusal: the resolver must report an error containing `needle`.
  refusals = {
    unknown-neighbour = {
      needle = "no monitor instance is named \"nope\"";
      input = { monitors.a.mode = uhd; layout.a.position.rightOf = "nope"; };
    };
    unknown-layout-name = {
      needle = "layout.ghost: no monitor instance";
      input = { monitors.a.mode = uhd; layout.ghost.scale = 2.0; };
    };
    unknown-mirror = {
      needle = "mirror = \"nope\"";
      input = { monitors.a.mode = uhd; layout.a.mirror = "nope"; };
    };
    cycle = {
      needle = "placement cycle";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; };
        layout = { a.position.rightOf = "b"; b.position.rightOf = "a"; };
      };
    };
    overlap = {
      needle = "overlap";
      input = {
        monitors = { a.mode = uhd; b.mode = qhd; };
        layout = { a.position = { x = 0; y = 0; }; b.position = { x = 100; y = 100; }; };
      };
    };
    missing-mode = {
      needle = "needs a concrete mode";
      input = {
        monitors = { a.mode = uhd; b.mode = "highres"; };
        layout.b.position.below = "a";
      };
    };
    missing-neighbour-mode = {
      needle = "on its neighbour \"a\"";
      input = {
        monitors = { a.mode = "preferred"; b.mode = uhd; };
        layout.b.position.below = "a";
      };
    };
    fractional-logical-size = {
      needle = "whole logical pixels";
      input = { monitors.a.mode = qhd; layout.a.scale = 1.5; };
    };
    malformed-position = {
      needle = "set both x and y, or one of";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; };
        layout.b.position = { x = 0; rightOf = "a"; };
      };
    };
    # Hyprland 0.57 setMirror: "Cannot mirror self!" / "Cannot mirror a mirror!"
    # -- it logs and leaves the output unmirrored, so refuse both at eval.
    mirror-self = {
      needle = "cannot mirror itself";
      input = { monitors.a.mode = uhd; layout.a.mirror = "a"; };
    };
    mirror-of-a-mirror = {
      needle = "is itself a mirror";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; c.mode = uhd; };
        layout = { b.mirror = "a"; c.mirror = "b"; };
      };
    };
    # setMirror moves every workspace off a mirror.
    workspaces-on-a-mirror = {
      needle = "a mirror holds no workspaces";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; };
        layout = { b = { mirror = "a"; workspaces = [ 3 ]; }; };
      };
    };
    # One workspace, one monitor: two rules for workspace 1 cannot both hold.
    workspace-on-two-monitors = {
      needle = "workspace 1 is assigned to";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; };
        layout = { a.workspaces = [ 1 2 ]; b = { position.rightOf = "a"; workspaces = [ 1 ]; }; };
      };
    };
    beside-a-mirror = {
      needle = "mirror or disabled";
      input = {
        monitors = { a.mode = uhd; b.mode = uhd; c.mode = uhd; };
        layout = { b.mirror = "a"; c.position.rightOf = "b"; };
      };
    };
  };

  caseFailures = lib.mapAttrsToList
    (n: c: "${n}: got ${builtins.toJSON c.got}, want ${builtins.toJSON c.want}")
    (lib.filterAttrs (_: c: c.got != c.want) cases);

  refusalFailures = lib.mapAttrsToList
    (n: r: "${n}: no error mentions '${r.needle}' (errors: ${builtins.toJSON (resolve r.input).errors})")
    (lib.filterAttrs (_: r: !(lib.any (lib.hasInfix r.needle) (resolve r.input).errors)) refusals);

  failures = caseFailures ++ refusalFailures;
in
{
  display-layout =
    if failures != [ ] then
      throw ("display layout resolver:\n  " + lib.concatStringsSep "\n  " failures)
    else
      pkgs.runCommand "display-layout" { } ''
        echo "PASS: ${toString (lib.length (lib.attrNames cases))} placements, ${toString (lib.length (lib.attrNames refusals))} refusals"
        touch $out
      '';
}
