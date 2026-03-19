# Changelog

All notable changes to mynixos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.4](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.9.3...mynixos-v0.9.4) (2026-03-19)


### Bug Fixes

* **legion,security,performance:** port skyspy-dev hardware fixes ([#112](https://github.com/i-am-logger/mynixos/issues/112)) ([cb03c72](https://github.com/i-am-logger/mynixos/commit/cb03c723b667aee52ac3360de7de816aab8ceaf4))

## [0.9.3](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.9.2...mynixos-v0.9.3) (2026-03-19)


### Bug Fixes

* **hyprland:** use layoutmsg for togglesplit (removed in newer Hyprland) ([4e9e76c](https://github.com/i-am-logger/mynixos/commit/4e9e76cf8f99ae06b1ccc92fd12eff40d61a460b))

## [0.9.2](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.9.1...mynixos-v0.9.2) (2026-03-19)


### Bug Fixes

* **hypr-vogix:** use exec instead of exec-once for live reload on switch ([6ae5eb8](https://github.com/i-am-logger/mynixos/commit/6ae5eb8322e6d17cf1755b696d0ae35a0082cc91))

## [0.9.1](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.9.0...mynixos-v0.9.1) (2026-03-19)


### Bug Fixes

* **openclaw:** disable PrivateDevices (needs os.networkInterfaces) ([70c8d9e](https://github.com/i-am-logger/mynixos/commit/70c8d9e616ef1b774d558cf9da54059121443406))

## [0.9.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.8.0...mynixos-v0.9.0) (2026-03-19)


### ⚠ BREAKING CHANGES

* rename claudeProxy to claudeCodeProxy, auto-enable tor onion service

### Code Refactoring

* rename claudeProxy to claudeCodeProxy, auto-enable tor onion service ([4fb05ba](https://github.com/i-am-logger/mynixos/commit/4fb05ba199c3a3bb212c852b71ceb158007c000b))

## [0.8.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.7.0...mynixos-v0.8.0) (2026-03-19)


### Features

* **claude-proxy:** upgrade to 0.4.0, bind to 127.0.0.1, pass API key via env ([2afec7b](https://github.com/i-am-logger/mynixos/commit/2afec7b226a9b806d2b56a02f3270155b09b5ce1))


### Bug Fixes

* **openclaw:** dedicated openclaw group for client config access ([2e5390a](https://github.com/i-am-logger/mynixos/commit/2e5390a33a83a248b38298f063fbfbd9f1784f02))
* **openclaw:** security hardening and review fixes ([5b99273](https://github.com/i-am-logger/mynixos/commit/5b99273597cd7dfe203a6d5ebe17bde133780a8e))

## [0.7.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.6.0...mynixos-v0.7.0) (2026-03-19)


### Features

* **claude-code:** enable experimental agent teams env var ([1d6cfe2](https://github.com/i-am-logger/mynixos/commit/1d6cfe2ca20bc7260233c7f26e78bb8538b82380))
* **network:** headscale + tailscale + tor mesh VPN modules ([93adb06](https://github.com/i-am-logger/mynixos/commit/93adb06878e180575969f815219b841c8d7597ec))
* **openssh:** auto-populate authorized_keys from YubiKey SSH public keys ([858fd9d](https://github.com/i-am-logger/mynixos/commit/858fd9db7b6aa868103686e857241aca937e9a8a))


### Bug Fixes

* **network:** resolve CI lint warnings (statix, deadnix) ([63aba06](https://github.com/i-am-logger/mynixos/commit/63aba06239aadd5e76e1222bb26cbef2cff31fc7))
* **network:** security and review hardening for mesh VPN modules ([e9eed02](https://github.com/i-am-logger/mynixos/commit/e9eed022bd826da00ec58a8529ad0d1c245c4234))
* **network:** security hardening, openssh module, local DERP map ([30d1b6b](https://github.com/i-am-logger/mynixos/commit/30d1b6b4788fa183b6caea4ae06dceb676e8cdb4))

## [0.6.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.5.0...mynixos-v0.6.0) (2026-03-19)


### Features

* **ai:** claude-code-proxy module, ollama enable option, openclaw provider auto-detect ([93e1f72](https://github.com/i-am-logger/mynixos/commit/93e1f7245f5860f8dd7126360b4d20569c3aa8db))
* **ai:** GPU-agnostic ollama + openclaw gateway module ([680d33e](https://github.com/i-am-logger/mynixos/commit/680d33e20dbeacacdf3b7b5fbd19413416ef6c4d))
* **claude-code:** add cloneConfigRepo option for syncing ~/.claude across machines ([2422934](https://github.com/i-am-logger/mynixos/commit/242293464aa87effeb7579d8d86d1f7ccc658824))
* **claude-proxy:** use claude-code-proxy 0.3.0 from crates.io ([6cc4857](https://github.com/i-am-logger/mynixos/commit/6cc4857a3533373917b911052e18fc5cfd166108))
* **claude-proxy:** use claude-proxy 0.2.0 from crates.io ([ff894e9](https://github.com/i-am-logger/mynixos/commit/ff894e90c2d4544b2ccefb536e9a2b6e8a4239db))


### Bug Fixes

* statix + treefmt lint warnings in AI modules ([8da40cd](https://github.com/i-am-logger/mynixos/commit/8da40cdf9cba8f780a42d2b309cf1f3c163947e4))
* use stateDir variable, fix treefmt formatting in AI modules ([a6bd304](https://github.com/i-am-logger/mynixos/commit/a6bd3048d4f4c89484aca012c767ddfd29a4bf15))

## [0.5.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.4.0...mynixos-v0.5.0) (2026-03-18)


### Features

* architecture review fixes, network defense expansion, and input deduplication ([83d7cfe](https://github.com/i-am-logger/mynixos/commit/83d7cfecc894c4c1739ee13893fb489af6a64cec))

## [0.4.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.3.0...mynixos-v0.4.0) (2026-03-17)


### Features

* add network defense docs and rename TSCM to network defense ([2e71ee5](https://github.com/i-am-logger/mynixos/commit/2e71ee59a1714716e1efbe6992c86e16c6cde312))

## [0.3.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.2.0...mynixos-v0.3.0) (2026-03-17)


### Features

* add hypr-vogix demo video and recording script ([3078ebb](https://github.com/i-am-logger/mynixos/commit/3078ebb6beaa4ef193ab2cc6c55fa01e65afdb64))

## [0.2.0](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.6...mynixos-v0.2.0) (2026-03-17)


### Features

* add network monitoring module (TSCM) ([1906c76](https://github.com/i-am-logger/mynixos/commit/1906c76086099aac998a601916b72df9b78679b1))
* integrate hypr-vogix as my.themes.hypr-vogix ([acb461e](https://github.com/i-am-logger/mynixos/commit/acb461ebcacd2c92e581dc429dffaacd3247c370))


### Bug Fixes

* updates ([efd91ed](https://github.com/i-am-logger/mynixos/commit/efd91ed90f440f8327bbb5efc3713f29579117a1))

## [0.1.6](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.5...mynixos-v0.1.6) (2026-03-13)


### Bug Fixes

* remove pkgs from option-definition time to prevent infinite recursion ([#76](https://github.com/i-am-logger/mynixos/issues/76)) ([1950d93](https://github.com/i-am-logger/mynixos/commit/1950d936e2cfb9633695429085cfbd0508f1f14d)), closes [#75](https://github.com/i-am-logger/mynixos/issues/75)

## [0.1.5](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.4...mynixos-v0.1.5) (2026-03-13)


### Bug Fixes

* add CI concurrency to cancel stale workflow runs ([d406df7](https://github.com/i-am-logger/mynixos/commit/d406df7ca1a20d54e5c3a5d2e009ce52227fb5a3))
* correct app option paths and add missing terminal options ([99d9e0d](https://github.com/i-am-logger/mynixos/commit/99d9e0d274bac3ba4db423a7119a1177961f14a9))
* force Node.js 24 for GitHub Actions runners ([453b1e7](https://github.com/i-am-logger/mynixos/commit/453b1e7547990d7d8deb842ebb4f65008945a9a7))
* make refactor commits trigger minor version bumps ([1c04508](https://github.com/i-am-logger/mynixos/commit/1c045086bc14af9ccddb789211e340408be71f7d))
* update GitHub Actions to Node.js 24 compatible versions ([547547b](https://github.com/i-am-logger/mynixos/commit/547547b1e346d4b20e27202f5c1aa2c60554b9c3))


### Code Refactoring

* add browser dependency guard for webapps ([#71](https://github.com/i-am-logger/mynixos/issues/71)) ([c6c78bf](https://github.com/i-am-logger/mynixos/commit/c6c78bf24c054fe835196659bf0d77232bd2e3c2)), closes [#52](https://github.com/i-am-logger/mynixos/issues/52)
* add path validation for persistence options ([#65](https://github.com/i-am-logger/mynixos/issues/65)) ([a189d09](https://github.com/i-am-logger/mynixos/commit/a189d0900fb7c2be62edf40a17eef131e7684856)), closes [#49](https://github.com/i-am-logger/mynixos/issues/49)
* add typed options for common Hyprland settings ([#69](https://github.com/i-am-logger/mynixos/issues/69)) ([e80b5bb](https://github.com/i-am-logger/mynixos/commit/e80b5bb1b2b9072725875e15de3d139105753d57)), closes [#48](https://github.com/i-am-logger/mynixos/issues/48)
* extract shared flake discovery script ([#59](https://github.com/i-am-logger/mynixos/issues/59)) ([59ef81b](https://github.com/i-am-logger/mynixos/commit/59ef81b40d3cf3613583f7319fda9b830b400ac1)), closes [#43](https://github.com/i-am-logger/mynixos/issues/43)
* remove commented-out stylix configuration ([#56](https://github.com/i-am-logger/mynixos/issues/56)) ([fd38b30](https://github.com/i-am-logger/mynixos/commit/fd38b30058a8963694366b45f85a56465b792b7f)), closes [#42](https://github.com/i-am-logger/mynixos/issues/42)
* remove dead appHelpers.shouldEnable API ([#55](https://github.com/i-am-logger/mynixos/issues/55)) ([3b8fe2c](https://github.com/i-am-logger/mynixos/commit/3b8fe2cec4e9130161408f6a4797272df749b60d)), closes [#41](https://github.com/i-am-logger/mynixos/issues/41)
* standardize app module enable check pattern ([#63](https://github.com/i-am-logger/mynixos/issues/63)) ([9cd0df3](https://github.com/i-am-logger/mynixos/commit/9cd0df3ec7a535187bf058aa1e37d6e11a30967a)), closes [#46](https://github.com/i-am-logger/mynixos/issues/46)
* standardize directory naming to kebab-case ([#72](https://github.com/i-am-logger/mynixos/issues/72)) ([11fceb8](https://github.com/i-am-logger/mynixos/commit/11fceb8d8813b2a2f36da1a477f7423e9e763dca)), closes [#51](https://github.com/i-am-logger/mynixos/issues/51)
* standardize feature flag derivation pattern ([#68](https://github.com/i-am-logger/mynixos/issues/68)) ([ff90cd0](https://github.com/i-am-logger/mynixos/commit/ff90cd0f65aec0d7d7bc2047c5958e771a57ad7f)), closes [#50](https://github.com/i-am-logger/mynixos/issues/50)


### Documentation

* add product overview document ([#73](https://github.com/i-am-logger/mynixos/issues/73)) ([205a3a1](https://github.com/i-am-logger/mynixos/commit/205a3a1f99f242575f662d1b85796ef77734e271))
* update README with version badge and current features ([#57](https://github.com/i-am-logger/mynixos/issues/57)) ([2e3eed4](https://github.com/i-am-logger/mynixos/commit/2e3eed4590c0e6bc07b0b517e1ca345d920bee57)), closes [#54](https://github.com/i-am-logger/mynixos/issues/54)

## [0.1.4](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.3...mynixos-v0.1.4) (2026-03-13)


### Code Refactoring

* extract activeUsers helper for filterAttrs fullName pattern ([8d4291b](https://github.com/i-am-logger/mynixos/commit/8d4291bdf492c18ff22f5cf8653b30ca47b5c2b0))
* extract activeUsers helper for filterAttrs fullName pattern ([25392ce](https://github.com/i-am-logger/mynixos/commit/25392cee549ce7bdaf9c691d87ee2ee31f202e17)), closes [#45](https://github.com/i-am-logger/mynixos/issues/45)
* replace attrsOf anything with proper types ([b8ebe41](https://github.com/i-am-logger/mynixos/commit/b8ebe4159a264e42dcb3cb4ba1be4c7579ed0238))
* replace attrsOf anything with proper types ([3fcf133](https://github.com/i-am-logger/mynixos/commit/3fcf133a8c9952e51c69f428625e8982aea69ecd)), closes [#47](https://github.com/i-am-logger/mynixos/issues/47)
* standardize allowUnfreePredicate into single source ([f532a7d](https://github.com/i-am-logger/mynixos/commit/f532a7dcc8f27016a7c07310eb1b99cf27382a90))
* standardize allowUnfreePredicate into single source ([45e4d80](https://github.com/i-am-logger/mynixos/commit/45e4d80dfe7258813d474b991c9de645005a29ae)), closes [#44](https://github.com/i-am-logger/mynixos/issues/44)

## [0.1.3](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.2...mynixos-v0.1.3) (2026-03-13)


### Bug Fixes

* gate release-please on CI with always() to handle skipped jobs ([bf48a14](https://github.com/i-am-logger/mynixos/commit/bf48a148fb083f11095ee5cea4c92a6592cb7f34))
* make release-please independent of CI jobs to prevent auto-skip ([80a0e34](https://github.com/i-am-logger/mynixos/commit/80a0e34ac9e2b897d8ae962b38104287beecd3a1))

## [0.1.2](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.1...mynixos-v0.1.2) (2026-03-13)


### Features

* Add backward-compatible namespace aliases for core and motd ([f9851b1](https://github.com/i-am-logger/mynixos/commit/f9851b1702b69225b399016820f00506c29d170c))
* add claude-code module, fix Hyprland compat, update flake inputs ([a1d3690](https://github.com/i-am-logger/mynixos/commit/a1d3690627ddcbabd0698fa27b33547b94b23a6d))
* Add cooling module options to flake.nix ([ec91cf0](https://github.com/i-am-logger/mynixos/commit/ec91cf0d60942af7ae0191baa6553117c1144a20))
* add HDMI audio EDID firmware and update hyprland config ([c945c56](https://github.com/i-am-logger/mynixos/commit/c945c56239044717068f0d3613ef841dfe8a9cb6))
* Add my.hardware namespace for motherboards, laptops, and cooling ([6926cbb](https://github.com/i-am-logger/mynixos/commit/6926cbbe4408791efbefb5c89913ead2ecefe1c6))
* Add user creation support with groups, avatar, and password ([ecea621](https://github.com/i-am-logger/mynixos/commit/ecea62124ae010a497e88b0000e36971554bdc48))
* Add user-level media and terminal feature categories ([27ee547](https://github.com/i-am-logger/mynixos/commit/27ee547be79ae40a788b30adeef655f9c8f40644))
* add vogix theming support and update vogix input to GitHub ([07c4418](https://github.com/i-am-logger/mynixos/commit/07c441817d6dc03c6787bf69d5010e39e46cdfab))
* added support for ccache ([f247bab](https://github.com/i-am-logger/mynixos/commit/f247bab87d80bfa7c0adb85ad6724cd9fbf381a6))
* change distribution name from nixos to mynixos ([eaa9f00](https://github.com/i-am-logger/mynixos/commit/eaa9f0047616d6769d0764be351915f1db27e430))
* Consolidate development tools and improve opinionated defaults ([a916f3d](https://github.com/i-am-logger/mynixos/commit/a916f3d97209e0a8edd163744d0df0884811cff1))
* github-runner auto-enables k3s directly, no manual setup needed ([f6dd503](https://github.com/i-am-logger/mynixos/commit/f6dd503d3886e6428c44d7b39cfa99a9d6ae4115))
* Hardware module restructuring with composable components ([57f177e](https://github.com/i-am-logger/mynixos/commit/57f177e630f6fe42de100c6426dd3cda24098d1d))
* **hardware:** Add NZXT Kraken Elite 240 RGB cooling module ([6405ddd](https://github.com/i-am-logger/mynixos/commit/6405dddefc9b740bae300f2a5bcfb5d60d6b83ad))
* initial mynixos implementation with typed functional DSL ([e094d09](https://github.com/i-am-logger/mynixos/commit/e094d0982194da2e703881c88017f326fdfc693e))
* Motherboard/laptop modules automatically set cpu/gpu/bluetooth/audio ([58de6ef](https://github.com/i-am-logger/mynixos/commit/58de6ef580f6a7b2095c899e8dd105e42b9ab900))
* Move element to user-level configuration ([1ffaf6c](https://github.com/i-am-logger/mynixos/commit/1ffaf6ccf8ce81febd9f7c899dd297c29eea8301))
* Move GitHub config to user.github namespace ([17f5ce4](https://github.com/i-am-logger/mynixos/commit/17f5ce4b04023fd870b81e5e5314e94360d194e2))
* Move signal and slack to user-level configuration ([0da4205](https://github.com/i-am-logger/mynixos/commit/0da4205b8959252700d8e9b1d311deffb2c69ee6))
* Move terminals (kitty, ghostty, wezterm) to user-level ([41931d4](https://github.com/i-am-logger/mynixos/commit/41931d4d78c7f938dab0a11e110e57beacab80f7))
* Populate read-only system flags in graphical/dev/streaming ([f2de256](https://github.com/i-am-logger/mynixos/commit/f2de256ab489633c4d91a795d7c0ef05fa31c451))
* Replace GDM with greetd for minimal Hyprland setup ([253daa2](https://github.com/i-am-logger/mynixos/commit/253daa2ef06f8c7b46ce680c944c53f84203c197))


### Bug Fixes

* add home.activation to automatically import YubiKey GPG keys ([c5dcbca](https://github.com/i-am-logger/mynixos/commit/c5dcbcaeb497ad19a7d9ed29123a731308a38d5b))
* Add my.video.streamdeck namespace and fix streaming module ([cd1130b](https://github.com/i-am-logger/mynixos/commit/cd1130b10039aade009a266cceadac59ffcc18e9))
* address code quality issues from review ([c551e61](https://github.com/i-am-logger/mynixos/commit/c551e61fa167b75abc832bf651338e5ff167eb0c))
* Address critical audit findings and add migration plan ([10a4533](https://github.com/i-am-logger/mynixos/commit/10a4533570bde553e3ba70af55a73cfbb1ad5db0))
* code quality improvements (issues [#11](https://github.com/i-am-logger/mynixos/issues/11)-[#34](https://github.com/i-am-logger/mynixos/issues/34)) ([f849b2d](https://github.com/i-am-logger/mynixos/commit/f849b2da0b95ff148c4241360d42d81328d92fd1))
* Complete architectural refactoring of mynixos (16 fixes across 3 rounds) ([46e5e42](https://github.com/i-am-logger/mynixos/commit/46e5e42192865f5e9aa2d6b14d10dd9d7588d58c))
* disable stylix module due to nixpkgs compatibility issues ([913d8c0](https://github.com/i-am-logger/mynixos/commit/913d8c020e36984de01bbd44e9b23517f4f10322))
* fix app persistence aggregation and distribute hardcoded paths to modules ([a88066a](https://github.com/i-am-logger/mynixos/commit/a88066acf95f99ef7931abf34a3c53f8c75203c4))
* fix CI by removing installer-iso job and formatting nix files ([5281c50](https://github.com/i-am-logger/mynixos/commit/5281c50cd4b3032a913ea1fe47fb030e8b36a5eb))
* Fix laptop module syntax and structure ([1e1ac62](https://github.com/i-am-logger/mynixos/commit/1e1ac62a486d1a0175be36b43215e83429d2b877))
* make cava stylix theming conditional on themes being enabled ([e0d9458](https://github.com/i-am-logger/mynixos/commit/e0d94586e67ce40243d64d488a53423abc6754a2))
* make cava-extended module work when stylix is disabled ([6e8eb4f](https://github.com/i-am-logger/mynixos/commit/6e8eb4fe3448e1ce06c797c9d7255060280589d2))
* Make v4l2loopback kernel module conditional on my.video.virtual.enable ([515cd7d](https://github.com/i-am-logger/mynixos/commit/515cd7d7900cbbc1a1d7581a0e480404597fc9be))
* Merge duplicate environment.systemPackages in github-runner ([e767c9d](https://github.com/i-am-logger/mynixos/commit/e767c9ddf20bee4ed1b8b6ab063e0ebab027d987))
* Merge duplicate systemd.services in github-runner ([227c508](https://github.com/i-am-logger/mynixos/commit/227c50854076546ed55281eb7db20244009e6e23))
* Move enable check into hardware directory modules ([061c097](https://github.com/i-am-logger/mynixos/commit/061c097f2118987484d585f2869608895ea13c9a))
* only disable identitiesOnly when YubiKey is present ([303aea8](https://github.com/i-am-logger/mynixos/commit/303aea8e30d5777188528b293e6634f23eb56ea6))
* pass token to release-please action to fix 401 on release creation ([eaf4268](https://github.com/i-am-logger/mynixos/commit/eaf426806b748581bcfbc9f09e55d1fb5cfbe6c9))
* Prevent infinite recursion in github-runner by requiring development to be enabled ([b99fcf7](https://github.com/i-am-logger/mynixos/commit/b99fcf706222498af1cc019e9f6e3dafdf7ba286))
* Remove conflicting greetd settings merge ([f2e90be](https://github.com/i-am-logger/mynixos/commit/f2e90be1fa89463685c8be1c874c2007c4e85303))
* Remove deprecated modules/ directory ([d7cd3da](https://github.com/i-am-logger/mynixos/commit/d7cd3da1600496a1f1a75d69488c31c7f472c8c0))
* Remove duplicate config (vm.max_map_count, NetworkManager, usbmuxd) ([73de1a0](https://github.com/i-am-logger/mynixos/commit/73de1a058de199be50564aff90ef373b8ba9b1cb))
* Remove duplicate xdg-desktop-portal-hyprland from home packages ([5ee9c5c](https://github.com/i-am-logger/mynixos/commit/5ee9c5c1f59f82c2b8c17954719b265309fccc3b))
* Remove extra closing paren in laptop module ([93563cd](https://github.com/i-am-logger/mynixos/commit/93563cda756a3c78c238f2724bc84791a386bce1))
* Remove k3s config from github-runner, only assert it's enabled ([9be0e0d](https://github.com/i-am-logger/mynixos/commit/9be0e0d5b705d3c96d7504ae8be2c5d921e8fbb3))
* Remove option definitions from CPU/GPU modules to avoid type conflicts ([9bbec68](https://github.com/i-am-logger/mynixos/commit/9bbec687407063497d17e524bd9865258763cd6d))
* Remove ROCm config from motherboard module to avoid attribute conflict ([385866b](https://github.com/i-am-logger/mynixos/commit/385866b80e582eca4e495966b834dd188f243eff))
* Resolve configurationLimit conflict in Legion laptop ([492f914](https://github.com/i-am-logger/mynixos/commit/492f914cf417fd1e758e9a3b165d02fca0e20b21))
* Resolve infinite recursion and undefined cfg in development.nix ([ef95007](https://github.com/i-am-logger/mynixos/commit/ef9500768fba876ca2f6ef2da135f124f7eb9232))
* set CCACHE_DIR system-wide for user ccache access ([87fbac6](https://github.com/i-am-logger/mynixos/commit/87fbac63abe424c9d92d6d5bce8a7b722ebd3606))
* set identitiesOnly = false for GitHub/GitLab/BitBucket to allow gpg-agent SSH keys ([50d9490](https://github.com/i-am-logger/mynixos/commit/50d9490cab300d001045cf150e0344398615a7c5))
* Standardize browser option to types.package for consistency ([42efeea](https://github.com/i-am-logger/mynixos/commit/42efeea49f2d52e624329b5d727ff8d5001ac2d0))
* Update home-manager and fix deprecated options ([ecb4f29](https://github.com/i-am-logger/mynixos/commit/ecb4f294c4fd06a3093d60e1344ef75b7ef11a75))
* Update home-manager deprecated options and add missing applications ([dbc6de2](https://github.com/i-am-logger/mynixos/commit/dbc6de2d113e2ac13ca5b8049936d4ae512b5ae9))
* Update infra modules to use new flattened paths ([69c1bad](https://github.com/i-am-logger/mynixos/commit/69c1bad4c716eb843f25661de1b9c7be902458cc))
* Use conditional imports for hardware wrapper modules ([d4da82a](https://github.com/i-am-logger/mynixos/commit/d4da82a876d39b6a43d330be35496a67a5e36f26))
* use manifest-based release-please config instead of standalone mode ([bcfdb81](https://github.com/i-am-logger/mynixos/commit/bcfdb8144aa14b25471795850f9a2fa3ad8480db))
* use mkDefault for networking.wireless.enable to avoid conflicts ([2464f18](https://github.com/i-am-logger/mynixos/commit/2464f1864553b7a49566af0bdb873b8cdf6ea7df))
* Use regular priority for environment variables to override nixpkgs defaults ([2d3ec4c](https://github.com/i-am-logger/mynixos/commit/2d3ec4cc5493a9e40461f3db448f52c937c11676))
* use systemd user service instead of home.activation for GPG key import ([4ae6d7a](https://github.com/i-am-logger/mynixos/commit/4ae6d7abe5cc6d0c232ed86c0c62175afb3f4c4d))
* **users:** Add missing home and group settings for created users ([872faca](https://github.com/i-am-logger/mynixos/commit/872faca56a58ff0e285c0afb16279d9fc264c902))


### Code Refactoring

* Add flattened API namespaces alongside existing structure ([3eaf5f6](https://github.com/i-am-logger/mynixos/commit/3eaf5f6f3b9c009b659e14f896c896d7e158c27b))
* Add user defaults namespace and fix EDITOR environment variable ([11aad94](https://github.com/i-am-logger/mynixos/commit/11aad941544a4602961bb4f30cbb8b612260a4c0))
* extract flake options to separate files and implement environment API ([7a6242c](https://github.com/i-am-logger/mynixos/commit/7a6242c6be85f253b49f20359cb66a3826030b49))
* Fix architecture violations and improve display manager API ([bc9285c](https://github.com/i-am-logger/mynixos/commit/bc9285c40e3dc849eccab4cf16536729135c64fa))
* Implement consistent user feature API across dev, ai, and webapps ([7bb5abc](https://github.com/i-am-logger/mynixos/commit/7bb5abc556c6d1a1a815724807c34e1edc5fe266))
* Merge my.features.core into my.system namespace ([18680cb](https://github.com/i-am-logger/mynixos/commit/18680cbe5297b67ac3f0f158e81bf8c0cb8b2bd1))
* Move browsers to user-level configuration ([773f984](https://github.com/i-am-logger/mynixos/commit/773f984abd5eee2f8379f5d83c7ae85e53b553a8))
* Move dev system services to my/dev/ ([1be8ff9](https://github.com/i-am-logger/mynixos/commit/1be8ff9059fdcd4ac3976a076f5d8fa3cbc1cecf))
* Move direnv and vscode to user-level apps ([fa39b69](https://github.com/i-am-logger/mynixos/commit/fa39b69ad5c25bcb47fda479dd3abb1262d25041))
* Move editors to user-level configuration ([db6fafe](https://github.com/i-am-logger/mynixos/commit/db6fafea56893a6f767ef0163a8dcb234f596004))
* Move fileManagers, multiplexers, viewers to user-level ([0f05b74](https://github.com/i-am-logger/mynixos/commit/0f05b74e408befd0fa21384eb51ff0f412b895eb))
* Move fileUtils, sysinfo, visualizers to user-level ([4abe380](https://github.com/i-am-logger/mynixos/commit/4abe380c833d75ed9e3ec24b913129166edae80f))
* Move final categories (dev, media, art, network, fun, finance) to user-level ([bfd29d3](https://github.com/i-am-logger/mynixos/commit/bfd29d362949b049a797c656617b4603040d2c88))
* Move github-runner under development feature ([3400909](https://github.com/i-am-logger/mynixos/commit/340090931fad2cd7dc9956a40f0d7b6ed5af9746))
* Move graphical system services to my/graphical/ ([af6080e](https://github.com/i-am-logger/mynixos/commit/af6080e3c97bdd9d37731c424c84460240bc4502))
* Move launchers, sync, utils to user-level ([80f899a](https://github.com/i-am-logger/mynixos/commit/80f899aab7464db617ba7e8ccbf2f91b09bdda84))
* Move shells and prompts to user-level configuration ([d25b645](https://github.com/i-am-logger/mynixos/commit/d25b645203a4eaf5d4f97d7cc556491e2042a45b))
* Move StreamDeck to hardware.peripherals.elgato ([39618de](https://github.com/i-am-logger/mynixos/commit/39618dec9d38161f1913cc387d9eae3b72dce2c5))
* Move TRIM service to storage hardware module ([83461bb](https://github.com/i-am-logger/mynixos/commit/83461bbc2abfd61c4daba1efec30d96f858f217e))
* remove dead terminal options and duplicate package code, guard git module ([036d84c](https://github.com/i-am-logger/mynixos/commit/036d84cc864cb0489332b4e47f2cf334479df748))
* Remove deprecated my.features namespace ([972f942](https://github.com/i-am-logger/mynixos/commit/972f942087600d80cdf8819d60bfd0a65135bede))
* Rename user defaults to environment for consistency ([dc67c77](https://github.com/i-am-logger/mynixos/commit/dc67c775f53d1ff57d83f09bcb3b025402f3fc26))
* Restructure mynixos from modules/ to my/ directory ([637e21d](https://github.com/i-am-logger/mynixos/commit/637e21d24f7f74b1e4b325792cb0f8306c5433f9))
* Separate v4l2loopback system config from user streaming config ([1cc623e](https://github.com/i-am-logger/mynixos/commit/1cc623ee4975cd1c0dcac98c3bff6f3cc4532f28))
* Simplify Docker to user-level (runs as user) ([179f621](https://github.com/i-am-logger/mynixos/commit/179f621fca34e6a91c34b1996045ca4687451120))
* Update webapps and remaining modules to new API ([e16456c](https://github.com/i-am-logger/mynixos/commit/e16456c14b3735057ecaf5ae05247c65b69a16d4))


### Documentation

* add comprehensive README and .gitignore ([664761e](https://github.com/i-am-logger/mynixos/commit/664761ea7cb6ce2f68842e000bae21485302e93e))
* fixed readme,md added contributing ([b7e327e](https://github.com/i-am-logger/mynixos/commit/b7e327e92eee967d82b7992e2e1b9c3d42158618))
* Update learning journals with media/terminal feature task feedback ([7ae18d1](https://github.com/i-am-logger/mynixos/commit/7ae18d174936a308c48d0ea6d009b5b85572019d))


### Miscellaneous

* **master:** release mynixos 0.1.1 ([d2fdcf0](https://github.com/i-am-logger/mynixos/commit/d2fdcf0e59ac50ad74ac9d47d01905e4ff25b8fb))
* **master:** release mynixos 0.1.1 ([81dd771](https://github.com/i-am-logger/mynixos/commit/81dd7714c003a525c9843be19023ea38d3af7a4c))
* update flake inputs ([048dbea](https://github.com/i-am-logger/mynixos/commit/048dbea7c22fd648b6876f88fa92dbb458960024))
* update flake inputs and format helix config ([87765c6](https://github.com/i-am-logger/mynixos/commit/87765c60bef25fc410fd220508078363c074d4f2))

## [0.1.1](https://github.com/i-am-logger/mynixos/compare/mynixos-v0.1.0...mynixos-v0.1.1) (2026-03-12)


### Features

* Add backward-compatible namespace aliases for core and motd ([f9851b1](https://github.com/i-am-logger/mynixos/commit/f9851b1702b69225b399016820f00506c29d170c))
* add claude-code module, fix Hyprland compat, update flake inputs ([a1d3690](https://github.com/i-am-logger/mynixos/commit/a1d3690627ddcbabd0698fa27b33547b94b23a6d))
* Add cooling module options to flake.nix ([ec91cf0](https://github.com/i-am-logger/mynixos/commit/ec91cf0d60942af7ae0191baa6553117c1144a20))
* add HDMI audio EDID firmware and update hyprland config ([c945c56](https://github.com/i-am-logger/mynixos/commit/c945c56239044717068f0d3613ef841dfe8a9cb6))
* Add my.hardware namespace for motherboards, laptops, and cooling ([6926cbb](https://github.com/i-am-logger/mynixos/commit/6926cbbe4408791efbefb5c89913ead2ecefe1c6))
* Add user creation support with groups, avatar, and password ([ecea621](https://github.com/i-am-logger/mynixos/commit/ecea62124ae010a497e88b0000e36971554bdc48))
* Add user-level media and terminal feature categories ([27ee547](https://github.com/i-am-logger/mynixos/commit/27ee547be79ae40a788b30adeef655f9c8f40644))
* add vogix theming support and update vogix input to GitHub ([07c4418](https://github.com/i-am-logger/mynixos/commit/07c441817d6dc03c6787bf69d5010e39e46cdfab))
* added support for ccache ([f247bab](https://github.com/i-am-logger/mynixos/commit/f247bab87d80bfa7c0adb85ad6724cd9fbf381a6))
* change distribution name from nixos to mynixos ([eaa9f00](https://github.com/i-am-logger/mynixos/commit/eaa9f0047616d6769d0764be351915f1db27e430))
* Consolidate development tools and improve opinionated defaults ([a916f3d](https://github.com/i-am-logger/mynixos/commit/a916f3d97209e0a8edd163744d0df0884811cff1))
* github-runner auto-enables k3s directly, no manual setup needed ([f6dd503](https://github.com/i-am-logger/mynixos/commit/f6dd503d3886e6428c44d7b39cfa99a9d6ae4115))
* Hardware module restructuring with composable components ([57f177e](https://github.com/i-am-logger/mynixos/commit/57f177e630f6fe42de100c6426dd3cda24098d1d))
* **hardware:** Add NZXT Kraken Elite 240 RGB cooling module ([6405ddd](https://github.com/i-am-logger/mynixos/commit/6405dddefc9b740bae300f2a5bcfb5d60d6b83ad))
* initial mynixos implementation with typed functional DSL ([e094d09](https://github.com/i-am-logger/mynixos/commit/e094d0982194da2e703881c88017f326fdfc693e))
* Motherboard/laptop modules automatically set cpu/gpu/bluetooth/audio ([58de6ef](https://github.com/i-am-logger/mynixos/commit/58de6ef580f6a7b2095c899e8dd105e42b9ab900))
* Move element to user-level configuration ([1ffaf6c](https://github.com/i-am-logger/mynixos/commit/1ffaf6ccf8ce81febd9f7c899dd297c29eea8301))
* Move GitHub config to user.github namespace ([17f5ce4](https://github.com/i-am-logger/mynixos/commit/17f5ce4b04023fd870b81e5e5314e94360d194e2))
* Move signal and slack to user-level configuration ([0da4205](https://github.com/i-am-logger/mynixos/commit/0da4205b8959252700d8e9b1d311deffb2c69ee6))
* Move terminals (kitty, ghostty, wezterm) to user-level ([41931d4](https://github.com/i-am-logger/mynixos/commit/41931d4d78c7f938dab0a11e110e57beacab80f7))
* Populate read-only system flags in graphical/dev/streaming ([f2de256](https://github.com/i-am-logger/mynixos/commit/f2de256ab489633c4d91a795d7c0ef05fa31c451))
* Replace GDM with greetd for minimal Hyprland setup ([253daa2](https://github.com/i-am-logger/mynixos/commit/253daa2ef06f8c7b46ce680c944c53f84203c197))


### Bug Fixes

* add home.activation to automatically import YubiKey GPG keys ([c5dcbca](https://github.com/i-am-logger/mynixos/commit/c5dcbcaeb497ad19a7d9ed29123a731308a38d5b))
* Add my.video.streamdeck namespace and fix streaming module ([cd1130b](https://github.com/i-am-logger/mynixos/commit/cd1130b10039aade009a266cceadac59ffcc18e9))
* Address critical audit findings and add migration plan ([10a4533](https://github.com/i-am-logger/mynixos/commit/10a4533570bde553e3ba70af55a73cfbb1ad5db0))
* Complete architectural refactoring of mynixos (16 fixes across 3 rounds) ([46e5e42](https://github.com/i-am-logger/mynixos/commit/46e5e42192865f5e9aa2d6b14d10dd9d7588d58c))
* disable stylix module due to nixpkgs compatibility issues ([913d8c0](https://github.com/i-am-logger/mynixos/commit/913d8c020e36984de01bbd44e9b23517f4f10322))
* fix app persistence aggregation and distribute hardcoded paths to modules ([a88066a](https://github.com/i-am-logger/mynixos/commit/a88066acf95f99ef7931abf34a3c53f8c75203c4))
* fix CI by removing installer-iso job and formatting nix files ([5281c50](https://github.com/i-am-logger/mynixos/commit/5281c50cd4b3032a913ea1fe47fb030e8b36a5eb))
* Fix laptop module syntax and structure ([1e1ac62](https://github.com/i-am-logger/mynixos/commit/1e1ac62a486d1a0175be36b43215e83429d2b877))
* make cava stylix theming conditional on themes being enabled ([e0d9458](https://github.com/i-am-logger/mynixos/commit/e0d94586e67ce40243d64d488a53423abc6754a2))
* make cava-extended module work when stylix is disabled ([6e8eb4f](https://github.com/i-am-logger/mynixos/commit/6e8eb4fe3448e1ce06c797c9d7255060280589d2))
* Make v4l2loopback kernel module conditional on my.video.virtual.enable ([515cd7d](https://github.com/i-am-logger/mynixos/commit/515cd7d7900cbbc1a1d7581a0e480404597fc9be))
* Merge duplicate environment.systemPackages in github-runner ([e767c9d](https://github.com/i-am-logger/mynixos/commit/e767c9ddf20bee4ed1b8b6ab063e0ebab027d987))
* Merge duplicate systemd.services in github-runner ([227c508](https://github.com/i-am-logger/mynixos/commit/227c50854076546ed55281eb7db20244009e6e23))
* Move enable check into hardware directory modules ([061c097](https://github.com/i-am-logger/mynixos/commit/061c097f2118987484d585f2869608895ea13c9a))
* only disable identitiesOnly when YubiKey is present ([303aea8](https://github.com/i-am-logger/mynixos/commit/303aea8e30d5777188528b293e6634f23eb56ea6))
* Prevent infinite recursion in github-runner by requiring development to be enabled ([b99fcf7](https://github.com/i-am-logger/mynixos/commit/b99fcf706222498af1cc019e9f6e3dafdf7ba286))
* Remove conflicting greetd settings merge ([f2e90be](https://github.com/i-am-logger/mynixos/commit/f2e90be1fa89463685c8be1c874c2007c4e85303))
* Remove deprecated modules/ directory ([d7cd3da](https://github.com/i-am-logger/mynixos/commit/d7cd3da1600496a1f1a75d69488c31c7f472c8c0))
* Remove duplicate config (vm.max_map_count, NetworkManager, usbmuxd) ([73de1a0](https://github.com/i-am-logger/mynixos/commit/73de1a058de199be50564aff90ef373b8ba9b1cb))
* Remove duplicate xdg-desktop-portal-hyprland from home packages ([5ee9c5c](https://github.com/i-am-logger/mynixos/commit/5ee9c5c1f59f82c2b8c17954719b265309fccc3b))
* Remove extra closing paren in laptop module ([93563cd](https://github.com/i-am-logger/mynixos/commit/93563cda756a3c78c238f2724bc84791a386bce1))
* Remove k3s config from github-runner, only assert it's enabled ([9be0e0d](https://github.com/i-am-logger/mynixos/commit/9be0e0d5b705d3c96d7504ae8be2c5d921e8fbb3))
* Remove option definitions from CPU/GPU modules to avoid type conflicts ([9bbec68](https://github.com/i-am-logger/mynixos/commit/9bbec687407063497d17e524bd9865258763cd6d))
* Remove ROCm config from motherboard module to avoid attribute conflict ([385866b](https://github.com/i-am-logger/mynixos/commit/385866b80e582eca4e495966b834dd188f243eff))
* Resolve configurationLimit conflict in Legion laptop ([492f914](https://github.com/i-am-logger/mynixos/commit/492f914cf417fd1e758e9a3b165d02fca0e20b21))
* Resolve infinite recursion and undefined cfg in development.nix ([ef95007](https://github.com/i-am-logger/mynixos/commit/ef9500768fba876ca2f6ef2da135f124f7eb9232))
* set CCACHE_DIR system-wide for user ccache access ([87fbac6](https://github.com/i-am-logger/mynixos/commit/87fbac63abe424c9d92d6d5bce8a7b722ebd3606))
* set identitiesOnly = false for GitHub/GitLab/BitBucket to allow gpg-agent SSH keys ([50d9490](https://github.com/i-am-logger/mynixos/commit/50d9490cab300d001045cf150e0344398615a7c5))
* Standardize browser option to types.package for consistency ([42efeea](https://github.com/i-am-logger/mynixos/commit/42efeea49f2d52e624329b5d727ff8d5001ac2d0))
* Update home-manager and fix deprecated options ([ecb4f29](https://github.com/i-am-logger/mynixos/commit/ecb4f294c4fd06a3093d60e1344ef75b7ef11a75))
* Update home-manager deprecated options and add missing applications ([dbc6de2](https://github.com/i-am-logger/mynixos/commit/dbc6de2d113e2ac13ca5b8049936d4ae512b5ae9))
* Update infra modules to use new flattened paths ([69c1bad](https://github.com/i-am-logger/mynixos/commit/69c1bad4c716eb843f25661de1b9c7be902458cc))
* Use conditional imports for hardware wrapper modules ([d4da82a](https://github.com/i-am-logger/mynixos/commit/d4da82a876d39b6a43d330be35496a67a5e36f26))
* use manifest-based release-please config instead of standalone mode ([bcfdb81](https://github.com/i-am-logger/mynixos/commit/bcfdb8144aa14b25471795850f9a2fa3ad8480db))
* use mkDefault for networking.wireless.enable to avoid conflicts ([2464f18](https://github.com/i-am-logger/mynixos/commit/2464f1864553b7a49566af0bdb873b8cdf6ea7df))
* Use regular priority for environment variables to override nixpkgs defaults ([2d3ec4c](https://github.com/i-am-logger/mynixos/commit/2d3ec4cc5493a9e40461f3db448f52c937c11676))
* use systemd user service instead of home.activation for GPG key import ([4ae6d7a](https://github.com/i-am-logger/mynixos/commit/4ae6d7abe5cc6d0c232ed86c0c62175afb3f4c4d))
* **users:** Add missing home and group settings for created users ([872faca](https://github.com/i-am-logger/mynixos/commit/872faca56a58ff0e285c0afb16279d9fc264c902))


### Code Refactoring

* Add flattened API namespaces alongside existing structure ([3eaf5f6](https://github.com/i-am-logger/mynixos/commit/3eaf5f6f3b9c009b659e14f896c896d7e158c27b))
* Add user defaults namespace and fix EDITOR environment variable ([11aad94](https://github.com/i-am-logger/mynixos/commit/11aad941544a4602961bb4f30cbb8b612260a4c0))
* extract flake options to separate files and implement environment API ([7a6242c](https://github.com/i-am-logger/mynixos/commit/7a6242c6be85f253b49f20359cb66a3826030b49))
* Fix architecture violations and improve display manager API ([bc9285c](https://github.com/i-am-logger/mynixos/commit/bc9285c40e3dc849eccab4cf16536729135c64fa))
* Implement consistent user feature API across dev, ai, and webapps ([7bb5abc](https://github.com/i-am-logger/mynixos/commit/7bb5abc556c6d1a1a815724807c34e1edc5fe266))
* Merge my.features.core into my.system namespace ([18680cb](https://github.com/i-am-logger/mynixos/commit/18680cbe5297b67ac3f0f158e81bf8c0cb8b2bd1))
* Move browsers to user-level configuration ([773f984](https://github.com/i-am-logger/mynixos/commit/773f984abd5eee2f8379f5d83c7ae85e53b553a8))
* Move dev system services to my/dev/ ([1be8ff9](https://github.com/i-am-logger/mynixos/commit/1be8ff9059fdcd4ac3976a076f5d8fa3cbc1cecf))
* Move direnv and vscode to user-level apps ([fa39b69](https://github.com/i-am-logger/mynixos/commit/fa39b69ad5c25bcb47fda479dd3abb1262d25041))
* Move editors to user-level configuration ([db6fafe](https://github.com/i-am-logger/mynixos/commit/db6fafea56893a6f767ef0163a8dcb234f596004))
* Move fileManagers, multiplexers, viewers to user-level ([0f05b74](https://github.com/i-am-logger/mynixos/commit/0f05b74e408befd0fa21384eb51ff0f412b895eb))
* Move fileUtils, sysinfo, visualizers to user-level ([4abe380](https://github.com/i-am-logger/mynixos/commit/4abe380c833d75ed9e3ec24b913129166edae80f))
* Move final categories (dev, media, art, network, fun, finance) to user-level ([bfd29d3](https://github.com/i-am-logger/mynixos/commit/bfd29d362949b049a797c656617b4603040d2c88))
* Move github-runner under development feature ([3400909](https://github.com/i-am-logger/mynixos/commit/340090931fad2cd7dc9956a40f0d7b6ed5af9746))
* Move graphical system services to my/graphical/ ([af6080e](https://github.com/i-am-logger/mynixos/commit/af6080e3c97bdd9d37731c424c84460240bc4502))
* Move launchers, sync, utils to user-level ([80f899a](https://github.com/i-am-logger/mynixos/commit/80f899aab7464db617ba7e8ccbf2f91b09bdda84))
* Move shells and prompts to user-level configuration ([d25b645](https://github.com/i-am-logger/mynixos/commit/d25b645203a4eaf5d4f97d7cc556491e2042a45b))
* Move StreamDeck to hardware.peripherals.elgato ([39618de](https://github.com/i-am-logger/mynixos/commit/39618dec9d38161f1913cc387d9eae3b72dce2c5))
* Move TRIM service to storage hardware module ([83461bb](https://github.com/i-am-logger/mynixos/commit/83461bbc2abfd61c4daba1efec30d96f858f217e))
* remove dead terminal options and duplicate package code, guard git module ([036d84c](https://github.com/i-am-logger/mynixos/commit/036d84cc864cb0489332b4e47f2cf334479df748))
* Remove deprecated my.features namespace ([972f942](https://github.com/i-am-logger/mynixos/commit/972f942087600d80cdf8819d60bfd0a65135bede))
* Rename user defaults to environment for consistency ([dc67c77](https://github.com/i-am-logger/mynixos/commit/dc67c775f53d1ff57d83f09bcb3b025402f3fc26))
* Restructure mynixos from modules/ to my/ directory ([637e21d](https://github.com/i-am-logger/mynixos/commit/637e21d24f7f74b1e4b325792cb0f8306c5433f9))
* Separate v4l2loopback system config from user streaming config ([1cc623e](https://github.com/i-am-logger/mynixos/commit/1cc623ee4975cd1c0dcac98c3bff6f3cc4532f28))
* Simplify Docker to user-level (runs as user) ([179f621](https://github.com/i-am-logger/mynixos/commit/179f621fca34e6a91c34b1996045ca4687451120))
* Update webapps and remaining modules to new API ([e16456c](https://github.com/i-am-logger/mynixos/commit/e16456c14b3735057ecaf5ae05247c65b69a16d4))


### Documentation

* add comprehensive README and .gitignore ([664761e](https://github.com/i-am-logger/mynixos/commit/664761ea7cb6ce2f68842e000bae21485302e93e))
* fixed readme,md added contributing ([b7e327e](https://github.com/i-am-logger/mynixos/commit/b7e327e92eee967d82b7992e2e1b9c3d42158618))
* Update learning journals with media/terminal feature task feedback ([7ae18d1](https://github.com/i-am-logger/mynixos/commit/7ae18d174936a308c48d0ea6d009b5b85572019d))


### Miscellaneous

* update flake inputs ([048dbea](https://github.com/i-am-logger/mynixos/commit/048dbea7c22fd648b6876f88fa92dbb458960024))
* update flake inputs and format helix config ([87765c6](https://github.com/i-am-logger/mynixos/commit/87765c60bef25fc410fd220508078363c074d4f2))

## [Unreleased]

### Removed (BREAKING CHANGE)

- **Removed `my.apps.*` namespace** - Use `my.users.<name>.apps.*` instead
  - The system-level `my.apps` namespace has been removed to eliminate duplication and confusion
  - All app configurations are now per-user via `my.users.<name>.apps.*`
  - This reduces flake.nix by 205 lines and provides clearer semantics
  - **Migration:** Change `my.apps.browsers.brave` to `my.users.<your-name>.apps.browsers.brave`
  - **Rationale:** Apps are inherently user preferences, not system-wide settings
  - Related fixes: alacritty and warp terminal modules now properly check per-user config

### Fixed

- **Terminal app namespace bugs** (alacritty, warp)
  - Fixed modules incorrectly using system-level `config.my.apps.terminals`
  - Now properly check per-user `userCfg.apps.terminals.*`
  - Prevents apps from being installed globally when only one user enables them

- **Removed deprecated options**
  - `my.hostname` (use `my.system.hostname`)
  - `my.users.<name>.githubUsername` (use `my.users.<name>.github.username`)
  - `my.users.<name>.editor` string (use `my.users.<name>.environment.editor` package)
  - `my.users.<name>.browser` string (use `my.users.<name>.environment.browser` package)

- **Impermanence Firefox persistence**
  - Changed from checking `config.my.apps.browsers.firefox` (wrong namespace)
  - Now unconditionally persists `.mozilla` directory (simpler and more reliable)

- **StreamDeck installation scope**
  - Changed from installing for ALL users when hardware enabled
  - Now only installs for users with `graphical.streaming.enable = true`
  - Prevents unnecessary packages for non-streaming users

### Added

- **Complete flake.nix Migration (Phases 1-4)**
  - **Phase 1**: Removed `my.apps.*` namespace (-205 lines)
  - **Phase 2**: Extracted all system options to 17 organized files (-1,528 lines)
  - **Phase 3**: Split users.nix into 10 specialized subdirectory files
  - **Phase 4**: Created reusable app option library (lib/app-options.nix)
  - **Final result**: flake.nix reduced from 2,018 to 259 lines (87.2% reduction)
  - **Total extracted**: 1,906 lines across 28 organized option files

- **New Directory Structure**
  - `options/` - All option definitions organized by namespace
  - `options/users/` - User-specific options in 10 focused files
  - `lib/app-options.nix` - Reusable library for app option patterns
  - Clean separation of concerns and improved maintainability

- **FLAKE_MIGRATION_PLAN.md**
  - Comprehensive plan for extracting flake.nix option definitions
  - All phases successfully completed
  - Exceeded targets (goal: 800-1000 lines, achieved: 259 lines)

## [0.1.0] - 2025-12-06

### Added

- Initial release of mynixos typed functional DSL
- Comprehensive hardware auto-detection (motherboards, laptops, CPUs, GPUs, peripherals)
- Feature-based configuration system (graphical, dev, ai, streaming, security)
- User-level configuration with opinionated defaults
- Impermanence support with automatic persistence
- YubiKey integration for SSH and GPG
- Secure boot support via Lanzaboote
- K3s and GitHub Actions runner infrastructure
- Stylix theming integration
- Home-manager integration with per-user packages
- AMD ROCm support for AI workloads (Ollama)
- OBS Studio streaming setup with virtual camera
- Hyprland window manager with opinionated defaults

---

**Note:** This project follows the philosophy that the API is unstable during initial development.
Breaking changes are acceptable and will be documented in this changelog.
