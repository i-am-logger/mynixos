# YubiKey on darwin

## Status

Not supported. `my.hardware.securityKeys` is declared in
`my/hardware/security-keys/options.nix`, which only `platforms/linux.nix` imports, so
setting it on a darwin host fails with ``The option `my.hardware.securityKeys' does not
exist``. `tests/user-option-reach.nix` asserts that reach.

This is a scope decision, not a technical limit. `aether5d-dev` authenticates sudo with
Touch ID (`my.hardware.biometrics`) and carries `pkgs.secretive` for a Secure Enclave SSH
key, so a YubiKey there is a second mechanism for something already covered.

## What macOS already does without any Nix wiring

macOS ships its own CCID driver — `/usr/libexec/SmartCardServices/drivers/ifd-ccid.bundle`
— and claims the key through `usbsmartcardreaderd` and `PCSC.framework`. So a YubiKey works
for GPG commit signing, SSH authentication and pass/gopass decryption with an empty
`GNUPGHOME`, no pcscd, no udev, no group membership and no root:

```
$ GNUPGHOME=$(mktemp -d /tmp/gh.XXXX) gpg --card-status
Reader ...........: Yubico YubiKey OTP FIDO CCID
Application type .: OpenPGP
Key attributes ...: ed25519 cv25519 ed25519
UIF setting ......: Sign=off Decrypt=on Auth=off
```

macOS needs **less** wiring than NixOS, not more.

## Why the Linux implementation does not port

`my/hardware/security-keys/yubico/` reaches the smartcard through options that do not exist
on a darwin host. Each of these is a hard evaluation error there:

`services.pcscd`, `services.yubikey-agent`, `services.udev`, `services.gnome`, the whole
`systemd.*` and `hardware.*` namespaces, `security.polkit`, `security.pam.u2f`,
`security.pam.services.{login,sudo,gdm}` (nix-darwin declares only `sudo_local`),
`programs.dconf`, `programs.ssh.startAgent` (`programs.ssh` carries only `extraConfig` and
`knownHosts`), `programs.gnupg.agent.pinentryPackage` (the agent carries only `enable` and
`enableSSHSupport`), `environment.sessionVariables`, `users.users.<n>.extraGroups`, and
the Linux-only `my.system.persistence.features`.

What survives is small: `environment.systemPackages`, `environment.etc`, `users.groups`,
`programs.gnupg.agent.{enable,enableSSHSupport}`, and the whole `home-manager.users.*` tree.

None of that is the feature. It is how Linux reaches a smartcard.

## What support would require

### File layout

```
my/hardware/security-keys/options.nix         -> platforms/common.nix
my/hardware/security-keys/yubico/default.nix  -> platforms/linux.nix
my/hardware/security-keys/yubico/darwin.nix   -> platforms/darwin.nix   (new, small)
my/hardware/security-keys/yubico/user.nix     -> imported by both       (the portable bulk
                                                                        of gpg.nix)
my/hardware/security-keys/yubico/linux.nix    -> imported by default.nix
```

This is the `my/hardware/biometrics` shape inverted: biometrics declares its options in
`my/hardware/biometrics/options.nix`, loaded only by `platforms/darwin.nix`, because only
darwin implements it; securityKeys would declare its options in a file
`platforms/common.nix` loads, because both would.

The option's *data* already crosses to darwin: `my.users.<n>.yubikeys` is declared in
`my/users/users/yubikeys-options.nix`, reached through `my/users/users/options.nix` in
`platforms/common.nix`; `aether5d-dev` carries the key list via `users/logger/default.nix`;
and `my/users/apps/ssh` reads its length to set `IdentitiesOnly=no`. Only the capability
flag is Linux-scoped.

### The darwin implementation is mostly subtraction

No daemon, no driver, no device permissions, no pinentry configuration — nixpkgs' gnupg is
built `--with-pinentry-pgm=<pinentry-mac>`, so the GUI prompt works out of the box. The bulk
of what is left is per-user home-manager config, but it does not port as written: the
`/home/${name}` paths, the `pinentry-gnome3` program line, the ungated `SSH_AUTH_SOCK`
export and the systemd user unit each need work before `gpg.nix` can be split into a shared
`user.nix`. Those are items 2, 4, 5 and 6 of the defect list below, so the same fixes buy
both a cleaner Linux module and a portable one.

### Touch ID and YubiKey coexist

`security.pam.services.sudo_local.text` is `types.lines`, so it merges.
`my/hardware/biometrics/apple` produces:

```
auth       optional       …/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
```

Appending with `lib.mkAfter` adds:

```
auth       sufficient     …/lib/security/pam_u2f.so authfile=/etc/u2f_keys origin=pam:// appid=pam:// cue
```

`sufficient` gives the wanted behaviour: Touch ID succeeds and the YubiKey is never reached;
Touch ID unavailable falls through to the key; both failing falls through to the rest of
`/etc/pam.d/sudo`, which is `pam_smartcard.so` then `pam_opendirectory.so`. Nobody can be
locked out.

Four details are load-bearing:

- The path is `lib/security/pam_u2f.so`, **not** `lib/pam/` (where `pam_reattach.so` lives).
- `origin=pam://` is **mandatory**. Left unset, pam-u2f uses `pam://$HOSTNAME` as the
  relying-party ID, which never matches a hostname-independent registration and silently
  always fails. `appid` defaults to the `origin` value and applies only to credentials
  created with pamu2fcfg v1.0.8 or earlier; `yubico/default.nix` sets both, so a darwin pam
  line passes both.
- `authfile` must be **absolute**. `openasuser` is the default whenever neither a global
  (absolute) authfile nor `XDG_CONFIG_HOME` is set, and the setuid'd process cannot read a
  root-owned file.
- Use `mkAfter`, never `mkBefore` — `mkBefore` places pam_u2f ahead of `pam_reattach` and
  breaks Touch ID inside a terminal multiplexer.

It should ship behind an opt-in defaulting to `false`: the pam_u2f runtime is unexercised.

### Signing

A Secure Enclave key is non-exportable and bound to one Mac — good for SSH auth, unusable as
a fleet identity, and structurally unable to decrypt the `pass` store. `yoga` and
`skyspy-dev` set `my.hardware.securityKeys.yubico.enable = true` and sign with the YubiKey,
so OpenPGP via the YubiKey is the one identity the two Linux hosts share, and the only
candidate for one that covers the Mac as well.

`IdentityAgent` is single-valued and overrides `SSH_AUTH_SOCK`, and
`systems/aether5d-dev/home.nix` points the `*` block at Secretive's socket, so gpg-agent and
Secretive cannot both own it. Give the OpenPGP auth subkey its own host alias under
`programs.ssh.settings` (`matchBlocks` is deprecated in favour of `settings`).

## Defects in the Linux implementation

These are worth fixing whether or not darwin support lands:

1. **The gates diverge.** `default.nix` gates on `cfg.enable || hasYubikey`; `gpg.nix` gates
   on `cfg.enable` alone. A host carrying yubikey serials without setting the flag gets
   device support but no GPG config. `gpg.nix` also re-sets `services.pcscd.enable` and
   `services.udev.packages`, which `default.nix` already sets under the wider gate.
2. **`/home/${name}` is hardcoded** in `gpg.nix` — the gopass `mounts.path` and the Brave
   native-messaging host path. Should be `config.home.homeDirectory`.
3. **`export PATH="$PATH:/usr/local/MacGPG2/bin"`** in the gopass wrapper script — a GPGTools
   path in a Linux-only module.
4. **`SSH_AUTH_SOCK` is exported ungated** from `bash.initExtra` / `zsh.initContent`, so it
   clobbers a forwarded agent socket. Both exports are redundant: `gpg.nix` also sets
   `services.gpg-agent.enableSshSupport = true`, which turns on home-manager's
   `misc/ssh-auth-sock.nix`, and that module wraps its own export in
   `if [ -z "$SSH_AUTH_SOCK" -o -z "$SSH_CONNECTION" ]` — precisely so a forwarded agent
   survives. Dropping the two hand-written exports leaves the guarded one.
5. **`pinentry-program /run/current-system/sw/bin/pinentry-gnome3`** is a path indirection
   that pins nothing; a store path is more correct.
6. **`systemd.user.services.import-yubikey-gpg-keys` is the one part of the home-manager
   block that cannot be shared.** It is unreachable from darwin — `gpg.nix` is imported by
   `my/hardware/security-keys/yubico/default.nix`, which only `platforms/linux.nix` pulls
   in — but a shared `user.nix` carrying it would fail open: home-manager's
   `systemd.user.enable` defaults to `pkgs.stdenv.isLinux` and its platform assertion sits
   inside `mkIf cfg.enable`, so the unit is dropped with no error and no warning. The
   portable replacement is `home.activation` with `lib.hm.dag.entryAfter [ "writeBoundary" ]`
   — which also retires the module's own comment claiming `lib.hm.dag` is unavailable here.
   It runs at activation rather than login, and activation failures are fatal to a rebuild in
   a way a failed user unit is not, so keep the `|| true` guards.

## Limits of the evidence

- **The Linux hosts cannot be built on an aarch64-darwin machine.** Option values evaluate
  fine, but `system.build.toplevel` needs an x86_64-linux builder at evaluation time, because
  vogix uses import-from-derivation. Linux claims here rest on source reading plus `nix eval`.
- **pam_u2f authenticating sudo on macOS is untested** — build-level and linkage-level
  evidence only.
- **Only `gpg --card-status` is exercised.** That proves the PC/SC chain. It does not prove a
  touch-gated signature or a `pass` decrypt completes through `pinentry-mac` under a
  launchd-started agent with no controlling terminal — the case where a curses pinentry hangs
  silently.
- **`nix flake check` proves nothing here.** mynixos exposes `checks` only for
  `x86_64-linux` and `aarch64-linux`, so on the Mac it runs no tests; and in the consumer
  flake it forces the `secrets` path input, which exists only on the Linux hosts.
- **`aether5d-dev` is not activated**: no `/run/current-system`, no `/etc/pam.d/sudo_local`,
  `darwin-rebuild` not on PATH. Its configuration is build-verified only, so apply and verify
  incrementally on the first switch.

## Footguns

- **`GNUPGHOME` path length.** A long `GNUPGHOME` makes the agent fail opaquely
  (`gpg: error running gpg-agent: exit status 2`); the identical command under `/tmp/gh.XXXX`
  succeeds. home-manager sidesteps this by placing darwin sockets under
  `/private/var/run/org.nix-community.home.gpg-agent/` — a reason to use its module rather
  than `programs.gnupg.agent`.
- **`scdaemonSettings.disable-ccid` is inert on darwin.** nixpkgs' gnupg is built
  `--disable-ccid-driver`, so there is no internal driver to disable.
- **Apple's OpenSSH advertises `sk-ssh-ed25519@openssh.com` but fails enrollment** with
  `No FIDO SecurityKeyProvider specified`. nixpkgs' openssh is built
  `--with-security-key-builtin=yes` and ships `libexec/ssh-sk-helper`, so it needs no
  provider. Apple's man pages claim built-in USB HID support and are wrong.
- **`yubico-pam` declares no `meta.platforms`**, so its apparent darwin availability is the
  unrestricted default, not a tested claim. `pam_u2f` lists `aarch64-darwin`; use that.
- **PIV pairing is not declarative.** `/etc/pam.d/sudo` runs `pam_smartcard.so`, so a
  PIV-paired YubiKey is a sudo factor with no Nix involvement — but `sc_auth pair` writes to
  Open Directory and cannot be expressed in configuration.
