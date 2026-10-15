'use strict';

// Writes, for one glyph variant, the config.toml text herdr-radar's
// `configure` action would put between its marker comments, so a Nix
// configuration can declare the same tables. Run at build time only:
//
//   node reference-config.js <plugin root> <variant> <out dir>
//
// The variant is read from HERDR_PLUGIN_CONFIG_DIR/config.toml at require
// time (lib/config.js), so the caller sets that up per run. Only pure
// builders are called: managed-config's apply() would spawn `defaults` and
// `herdr config check` and write config.toml, which is exactly what this
// replaces.

const fs = require('node:fs');
const path = require('node:path');

const [root, variant, out] = process.argv.slice(2);
const managed = require(path.join(root, 'lib', 'managed-config'));
const palette = require(path.join(root, 'lib', 'palette'));
const logos = require(path.join(root, 'lib', 'logos'));
const font = require(path.join(root, 'lib', 'font'));

if (logos.resolveVariant() !== variant) {
  throw new Error(`asked for ${variant}, the plugin resolved ${logos.resolveVariant()}`);
}

fs.mkdirSync(out, { recursive: true });
for (const appearance of ['light', 'dark']) {
  // themeBlock() is not exported; this is its body with no [colors]
  // overrides, which is what a fresh plugin config gives.
  const theme = Object.entries(palette.chrome[appearance]).map(([key, value]) => `${key} = "${value}"`);
  const text = [
    `# herdr-radar ${variant} glyphs, ${appearance} appearance.`,
    '# The tab-bar lines go inside [ui]; @HERDR_PLUGIN_STATE_DIR@ is the',
    "# plugin's state directory (herdr's state dir + /plugins/hhdebb.herdr-radar).",
    managed.block(),
    '',
    '[theme.custom]',
    ...theme,
    '',
    managed.sidebarBlock(appearance),
    '',
  ].join('\n');
  fs.writeFileSync(path.join(out, `${variant}-${appearance}.toml`), text, 'utf8');
}

if (variant === 'font') {
  const lines = font.TERMINALS.flatMap((terminal) => [`# ${terminal.name}`, ...terminal.lines, '']);
  fs.writeFileSync(path.join(out, 'terminal-codepoint-maps.txt'), lines.join('\n'), 'utf8');
}
