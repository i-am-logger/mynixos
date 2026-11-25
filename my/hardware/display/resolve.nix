# my.hardware.display, flattened into what a backend renders and what the
# domain asserts. Pure: my/hardware/display reads `assertions`, and
# my/graphical/hyprland reads `instances` and `wildcard`.
#
#   import ./resolve.nix { inherit lib; } config.my.hardware.display
#   => {
#     instances  = <name> -> { name; path; cfg; selector; layout; };
#     wildcard   = { name; path; cfg; selector = ""; layout; };   # the built-in defaults
#     assertions = [ { assertion; message; } ];
#   }
#
# `selector` is `output` when set, else "desc:<make> <model>[ <serial>]" --
# compositors match a description by prefix, so the serial narrows it to one
# panel. `layout` is the resolved layout entry (./layout.nix): position "auto"
# or { x; y; }, plus scale, transform, mirror, enable, workspaces.
{ lib }:

cfg:

let
  inherit (lib) concatLists concatStringsSep filter mapAttrsToList;

  layoutLib = import ./layout.nix { inherit lib; };

  # Every declared instance, catalogued models and generic alike, with the
  # option path it was declared at.
  catalogued = concatLists (mapAttrsToList
    (vendor: models:
      if vendor == "generic" then [ ]
      else
        concatLists (mapAttrsToList
          (model: insts: mapAttrsToList (name: m: { inherit name; path = "monitors.${vendor}.${model}.${name}"; cfg = m; }) insts)
          models))
    cfg.monitors);
  generic = mapAttrsToList (name: m: { inherit name; path = "monitors.generic.${name}"; cfg = m; }) cfg.monitors.generic;
  all = catalogued ++ generic;

  selectorOf = m:
    if m.output != null then m.output
    else "desc:" + concatStringsSep " " (filter (s: s != null) [ m.make m.model m.serial ]);

  byName = lib.listToAttrs (map (i: lib.nameValuePair i.name i) all);

  resolved = layoutLib.resolve {
    monitors = lib.mapAttrs (_: i: { mode = if builtins.isAttrs i.cfg.mode then i.cfg.mode else i.cfg.nativeMode; }) byName;
    inherit (cfg) layout;
  };

  instances = lib.mapAttrs (name: i: i // { selector = selectorOf i.cfg; layout = resolved.entries.${name}; }) byName;

  # The built-in defaults, as an instance nothing declared: the wildcard rule.
  wildcard = {
    name = "*";
    path = "monitors.*";
    cfg = (lib.evalModules { modules = [ ./monitor-options.nix ]; }).config;
    selector = "";
    layout = layoutLib.defaults // { size = null; };
  };

  pathsOf = name: map (i: "my.hardware.display.${i.path}") (filter (i: i.name == name) all);
  duplicates = filter (n: lib.length (pathsOf n) > 1) (lib.unique (map (i: i.name) all));

  # Two instances clash when Hyprland would match both rules to one panel:
  # equal selectors, or -- since desc: is a PREFIX match on "make model
  # serial" -- one desc: selector that is a prefix of the other (a serial-less
  # rule also catches the serialled panel of the same model).
  sameTarget = a: b:
    let
      sa = selectorOf a.cfg;
      sb = selectorOf b.cfg;
      desc = lib.hasPrefix "desc:";
    in
    sa == sb || (desc sa && desc sb && (lib.hasPrefix sa sb || lib.hasPrefix sb sa));
  clashes = concatLists (lib.imap0
    (i: a: map (b: { inherit a b; }) (filter (sameTarget a) (lib.drop (i + 1) all)))
    all);

  perInstance = i:
    let
      at = "my.hardware.display.${i.path}";
      m = i.cfg;
    in
    [
      {
        assertion = !m.hdr.enable || m.bitDepth == 10;
        message = "${at}: HDR needs bitDepth = 10. Set hdr.enable = false for an 8-bit link.";
      }
      {
        assertion = !(m.hdr.enable && m.hdr.icc != null);
        message = "${at}: hdr.icc and hdr.enable exclude each other -- an ICC profile is for SDR colour management. Set hdr.enable = false to use it.";
      }
    ];

  assertions =
    map
      (n: {
        assertion = false;
        message = "my.hardware.display: the monitor name \"${n}\" is declared more than once (${concatStringsSep ", " (pathsOf n)}). layout refers to monitors by name, so names must be unique across models.";
      })
      duplicates
    ++ map
      (c: {
        assertion = false;
        message = "my.hardware.display: my.hardware.display.${c.a.path} (\"${selectorOf c.a.cfg}\") and my.hardware.display.${c.b.path} (\"${selectorOf c.b.cfg}\") would all match the same panel; set serial or output on each so they name different panels.";
      })
      clashes
    ++ map
      (i: {
        assertion = i.cfg.output != null || (i.cfg.make != null && i.cfg.model != null);
        message = "my.hardware.display.${i.path}: set output, or make and model, so the monitor can be found.";
      })
      generic
    ++ concatLists (map perInstance all)
    ++ map (message: { assertion = false; inherit message; }) resolved.errors;
in
{
  inherit instances wildcard assertions;
}
