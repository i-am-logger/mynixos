# Themes aggregation module
# Imports all theme system implementations (stylix, vogix, etc.)
{ ... }:

{
  imports = [
    ./stylix
    ./vogix
    ./hypr-vogix
    ./openrgb
  ];
}
