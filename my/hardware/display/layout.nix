# The layout resolver: where each named monitor sits, in whole logical pixels.
#
# Pure: `lib` in, data out, no module system. tests/display-layout.nix drives it
# directly, and my/hardware/display turns its `errors` into assertions, so a bad
# layout NEVER throws here -- it reports, and the caller decides.
#
#   resolve {
#     monitors = <name> -> { mode = null | { width; height; ... }; };
#     layout   = <name> -> { position; scale; transform; mirror; enable; };
#   }
#   => {
#     errors  = [ str ];
#     entries = <name> -> {
#       position = "auto" | { x; y; };
#       size     = null | { width; height; };   # logical: mode / scale, swapped at 90/270
#       scale; transform; mirror; enable; workspaces;
#     };
#   }
#
# `position` is "auto", { x; y; } or { leftOf|rightOf|above|below = "<name>";
# align = "start"|"center"|"end"; }. A monitor with no layout entry is "auto" at
# scale 1. A monitor that is "auto" but named as someone's neighbour becomes the
# anchor at 0,0 -- that is what "put the laptop below the external" means when
# the external itself was never placed. Mirrors and disabled monitors take no
# part in placement. After placement every concrete position is shifted so the
# smallest x and y are 0, because Hyprland's layout has no negative space.
{ lib }:

let
  relations = [ "leftOf" "rightOf" "above" "below" ];

  defaults = {
    position = "auto";
    scale = 1.0;
    transform = { rotation = 0; flipped = false; };
    mirror = null;
    enable = true;
    workspaces = [ ];
  };

  round = x: builtins.floor (x + 0.5);
  abs = x: if x < 0 then -x else x;

  relationOf = pos:
    if pos == "auto" then null
    else lib.findFirst (r: (pos.${r} or null) != null) null relations;

  isAbsolute = pos: pos != "auto" && (pos.x or null) != null && (pos.y or null) != null;

  # Exactly one form: both x and y, or exactly one relation.
  wellFormed = pos:
    let
      nRel = lib.length (lib.filter (r: (pos.${r} or null) != null) relations);
      anyXY = (pos.x or null) != null || (pos.y or null) != null;
    in
    pos == "auto" || (nRel == 0 && isAbsolute pos) || (nRel == 1 && !anyXY);

  resolve = { monitors, layout }:
    let
      names = lib.attrNames monitors;

      entryOf = name: defaults // (layout.${name} or { })
        // { transform = defaults.transform // ((layout.${name} or { }).transform or { }); };
      entries0 = lib.genAttrs names entryOf;

      # Logical size, or null when the mode is not concrete.
      sizeOf = name:
        let
          inherit (monitors.${name}) mode;
          e = entries0.${name};
          w = mode.width / (e.scale * 1.0);
          h = mode.height / (e.scale * 1.0);
          swapped = e.transform.rotation == 90 || e.transform.rotation == 270;
        in
        if mode == null || !(builtins.isAttrs mode) then null
        else if swapped then { width = round h; height = round w; }
        else { width = round w; height = round h; };

      fractional = name:
        let
          inherit (monitors.${name}) mode;
          s = entries0.${name}.scale * 1.0;
          frac = x: abs (x - round x) > 0.01;
        in
        mode != null && builtins.isAttrs mode
        && (frac (mode.width / s) || frac (mode.height / s));

      sizes = lib.genAttrs names sizeOf;

      placeable = name: monitors ? ${name} && entries0.${name}.enable && entries0.${name}.mirror == null;

      # One monitor's raw position: { x; y; } or { error; }. `stack` is the chain
      # of monitors waiting on this one, which is how a cycle is seen.
      place = stack: name:
        let
          e = entries0.${name};
          pos = e.position;
          rel = relationOf pos;
          target = if rel == null then null else pos.${rel};
          align = if pos == "auto" then "start" else pos.align or "start";
          me = sizes.${name};
          them = sizes.${target};
          along = mine: start: span:
            if align == "center" then start + builtins.floor ((span - mine) / 2.0)
            else if align == "end" then start + span - mine
            else start;
          anchor = place (stack ++ [ name ]) target;
        in
        if builtins.elem name stack then
          { error = "my.hardware.display.layout: placement cycle ${lib.concatStringsSep " -> " (stack ++ [ name ])}"; }
        else if pos == "auto" then { x = 0; y = 0; }
        else if !(wellFormed pos) then
          { error = "my.hardware.display.layout.${name}.position: set both x and y, or one of ${lib.concatStringsSep "/" relations}"; }
        else if isAbsolute pos then { inherit (pos) x y; }
        else if !(monitors ? ${target}) then
          { error = "my.hardware.display.layout.${name}.position.${rel} = \"${target}\": no monitor instance is named \"${target}\""; }
        else if !(placeable target) then
          { error = "my.hardware.display.layout.${name}.position.${rel} = \"${target}\": that monitor is a mirror or disabled, so it has no place to be beside"; }
        else if me == null then
          { error = "my.hardware.display.layout.${name}: relative placement needs a concrete mode ({ width; height; refresh; }) on \"${name}\", or a model with a native mode"; }
        else if them == null then
          { error = "my.hardware.display.layout.${name}: relative placement needs a concrete mode ({ width; height; refresh; }) on its neighbour \"${target}\", or a model with a native mode"; }
        else if anchor ? error then anchor
        else if rel == "rightOf" then { x = anchor.x + them.width; y = along me.height anchor.y them.height; }
        else if rel == "leftOf" then { x = anchor.x - me.width; y = along me.height anchor.y them.height; }
        else if rel == "below" then { x = along me.width anchor.x them.width; y = anchor.y + them.height; }
        else { x = along me.width anchor.x them.width; y = anchor.y - me.height; };

      placedNames = lib.filter placeable names;

      # Monitors someone is placed beside. An "auto" one among them is the anchor.
      referenced = lib.unique (lib.concatMap
        (n:
          let r = relationOf entries0.${n}.position; in
          lib.optional (r != null) entries0.${n}.position.${r})
        placedNames);

      concrete = n:
        let p = entries0.${n}.position; in
        p != "auto" || builtins.elem n referenced;

      raw = lib.genAttrs (lib.filter concrete placedNames) (place [ ]);

      rawErrors = lib.unique (lib.concatMap (r: lib.optional (r ? error) r.error) (lib.attrValues raw));
      good = lib.filterAttrs (_: r: !(r ? error)) raw;

      dx = if good == { } then 0 else lib.foldl' (acc: r: lib.min acc r.x) (lib.head (lib.attrValues good)).x (lib.attrValues good);
      dy = if good == { } then 0 else lib.foldl' (acc: r: lib.min acc r.y) (lib.head (lib.attrValues good)).y (lib.attrValues good);
      shifted = lib.mapAttrs (_: r: { x = r.x - dx; y = r.y - dy; }) good;

      # Positive-area intersection between two placed monitors with known sizes.
      overlaps = a: b:
        let
          pa = shifted.${a};
          pb = shifted.${b};
          sa = sizes.${a};
          sb = sizes.${b};
        in
        sa != null && sb != null
        && pa.x < pb.x + sb.width && pb.x < pa.x + sa.width
        && pa.y < pb.y + sb.height && pb.y < pa.y + sa.height;

      # workspace number -> the monitors that claim it.
      workspaceOwners = lib.zipAttrs (lib.concatMap
        (n: map (ws: { ${toString ws} = n; }) entries0.${n}.workspaces)
        names);

      shiftedNames = lib.attrNames shifted;
      pairs = lib.concatLists (lib.imap0
        (i: a: map (b: { inherit a b; }) (lib.drop (i + 1) shiftedNames))
        shiftedNames);

      errors =
        map (n: "my.hardware.display.layout.${n}: no monitor instance is named \"${n}\"")
          (lib.filter (n: !(monitors ? ${n})) (lib.attrNames layout))
        ++ map (n: "my.hardware.display.layout.${n}.mirror = \"${entries0.${n}.mirror}\": no monitor instance is named \"${entries0.${n}.mirror}\"")
          (lib.filter (n: entries0.${n}.mirror != null && !(monitors ? ${entries0.${n}.mirror})) names)
        ++ rawErrors
        ++ map (p: "my.hardware.display.layout: \"${p.a}\" and \"${p.b}\" overlap") (lib.filter (p: overlaps p.a p.b) pairs)
        # Hyprland 0.57 setMirror refuses both ("Cannot mirror self!", "Cannot
        # mirror a mirror!") at runtime and leaves the output unmirrored.
        ++ map (n: "my.hardware.display.layout.${n}.mirror: a monitor cannot mirror itself")
          (lib.filter (n: entries0.${n}.mirror == n) names)
        ++ map (n: "my.hardware.display.layout.${n}.mirror = \"${entries0.${n}.mirror}\": that monitor is itself a mirror, and Hyprland cannot mirror a mirror")
          (lib.filter (n: let t = entries0.${n}.mirror; in t != null && t != n && entries0 ? ${t} && entries0.${t}.mirror != null) names)
        # setMirror moves every workspace off the mirroring output.
        ++ map (n: "my.hardware.display.layout.${n}.workspaces: a mirror holds no workspaces; give them to the monitor it mirrors")
          (lib.filter (n: entries0.${n}.mirror != null && entries0.${n}.workspaces != [ ]) names)
        ++ lib.mapAttrsToList (ws: owners: "my.hardware.display.layout: workspace ${ws} is assigned to ${lib.concatStringsSep " and " (lib.unique owners)}; a workspace lives on one monitor")
          (lib.filterAttrs (_: owners: lib.length (lib.unique owners) > 1) workspaceOwners)
        # A disabled monitor renders only `disabled`, so its scale is never applied.
        ++ map (n: "my.hardware.display.layout.${n}.scale = ${builtins.toJSON entries0.${n}.scale}: the mode does not divide into whole logical pixels, which Hyprland requires") (lib.filter (n: entries0.${n}.enable && fractional n) names);
    in
    {
      inherit errors;
      entries = lib.mapAttrs
        (n: e: e // {
          position = shifted.${n} or "auto";
          size = sizes.${n};
        })
        entries0;
    };
in
{
  inherit resolve defaults;
}
