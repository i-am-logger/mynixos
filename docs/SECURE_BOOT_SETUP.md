# Secure Boot Setup Guide

## ⚠️ CRITICAL SAFETY WARNINGS ⚠️

**READ THESE WARNINGS BEFORE PROCEEDING:**

1. **DUAL-BOOT USERS**: If you're dual-booting with Windows and using BitLocker:
   - Export your BitLocker recovery keys BEFORE starting
   - Verify they are correct and accessible
   - You WILL need them after enabling secure boot
   - Reference: [Microsoft BitLocker Recovery](https://support.microsoft.com/en-us/windows/finding-your-bitlocker-recovery-key-in-windows-6b71ad27-0b89-ea08-f143-056f5ab347d6)

2. **BACKUP REQUIREMENTS**:
   - Have a NixOS recovery USB ready
   - Know how to boot from USB and disable secure boot in BIOS
   - Backup important data before proceeding

3. **BIOS PASSWORD**: Set a BIOS password to prevent unauthorized secure boot changes

## Prerequisites Check

Before starting, verify these requirements:

```bash
# Check if system is UEFI and using systemd-boot
sudo bootctl status
```

Expected output should show:
- `Firmware: UEFI`
- `Current Boot Loader: systemd-boot`

If these aren't met, DO NOT PROCEED.

## Step 1: Build the System with Secure Boot Support

Build the system with secure boot enabled (`my.security.secureBoot.enable = true`):

```bash
sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
```

**IMPORTANT**: This step should complete successfully without errors. If there are build errors, fix them before proceeding.

## Step 2: Create Secure Boot Keys

Generate your secure boot keys using sbctl:

```bash
# Create the keys (this takes a few seconds)
sudo sbctl create-keys

# Verify keys were created
ls -la /var/lib/sbctl/keys/
```

You should see:
- `db/db.key` and `db.pem` (Database key and certificate)
- `KEK/KEK.key` and `KEK.pem` (Key Exchange Key)
- `PK/PK.key` and `PK.pem` (Platform Key)

## Step 3: Rebuild System to Sign Boot Files

Now rebuild the system again so lanzaboote can sign the boot files:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
```

## Step 4: Critical Validation - DO NOT SKIP

Verify that all necessary files are signed:

```bash
sudo sbctl verify
```

**EXPECTED OUTPUT EXAMPLE:**
```
Verifying file database and EFI images in /boot...
✓ /boot/EFI/BOOT/BOOTX64.EFI is signed
✓ /boot/EFI/Linux/nixos-generation-XXX.efi is signed
✓ /boot/EFI/systemd/systemd-bootx64.efi is signed
✗ /boot/EFI/nixos/kernel-XXX.efi is not signed
```

**CRITICAL**: It's EXPECTED that kernel files ending with `.efi` are NOT signed. This is normal.
**FAILURE CONDITION**: If UKI files (ending in `nixos-generation-XXX.efi`) are NOT signed, DO NOT PROCEED.

## Step 5: Test Boot Without Secure Boot

Reboot the system and ensure it boots normally:

```bash
sudo reboot
```

After reboot, verify the system is working normally and check boot status:

```bash
sudo bootctl status
```

Should show: `Secure Boot: disabled`

## Step 6: BIOS Configuration (BE VERY CAREFUL)

**READ THIS SECTION COMPLETELY BEFORE ENTERING BIOS**

### Entering Setup Mode

1. **Reboot and enter BIOS** (usually F1, F2, F12, or DEL during boot)
2. **Navigate to Security → Secure Boot**
3. **Enable Secure Boot** (if not already enabled)
4. **CRITICAL**: Select "Reset to Setup Mode" or "Enter Setup Mode"
   - **DO NOT** select "Clear All Secure Boot Keys" as this removes security databases
5. **Save and Exit** (usually F10)

### Alternative for Some Systems
If you don't see "Setup Mode" option:
- Look for option to "Delete Platform Key" or "Clear Platform Key"
- This should put the system in Setup Mode

## Step 7: Enroll Your Keys

Boot back into NixOS and enroll your keys:

```bash
# Enroll keys with Microsoft certificates (recommended for compatibility)
sudo sbctl enroll-keys --microsoft
```

**Expected output:**
```
Enrolling keys to EFI variables...
With vendor keys from microsoft...✓
Enrolled keys to the EFI variables!
```

## Step 8: Final Validation

Reboot the system:

```bash
sudo reboot
```

After boot, verify secure boot is active:

```bash
sudo bootctl status
```

**SUCCESS**: Should show `Secure Boot: enabled (user)`

## Step 9: Final Security Check

```bash
# Verify all signed files are still valid
sudo sbctl verify

# Check that secure boot is enforcing
dmesg | grep -i "secure boot"
```

## Troubleshooting and Recovery

### If System Won't Boot After Enabling Secure Boot

1. **Boot from USB/Recovery**:
   - Use your NixOS recovery USB
   - Boot in UEFI mode

2. **Disable Secure Boot in BIOS**:
   - Enter BIOS setup
   - Navigate to Security → Secure Boot
   - Disable Secure Boot
   - Save and Exit

3. **Mount and Chroot**:
   ```bash
   # Mount your NixOS partition
   sudo mount /dev/YOUR-ROOT-PARTITION /mnt
   sudo mount /dev/YOUR-BOOT-PARTITION /mnt/boot
   
   # Chroot and rebuild
   sudo nixos-enter
   nixos-rebuild switch --flake /etc/nixos#<hostname>
   ```

### If Keys Are Corrupted or Lost

1. Disable Secure Boot in BIOS
2. Delete old keys:
   ```bash
   sudo rm -rf /var/lib/sbctl
   ```
3. Start over from Step 2

### Common Issues

- **"Setup Mode" not available**: Look for "Clear Platform Key" instead
- **Microsoft keys needed**: Some hardware requires `--microsoft` flag
- **Boot loops**: Disable secure boot in BIOS and rebuild system

## Dual-Boot Windows Users

After enabling secure boot:
1. Windows may complain about BitLocker
2. Enter your BitLocker recovery key when prompted
3. Windows should boot normally after key entry

## Security Considerations

### What Secure Boot Provides
- Prevents unauthorized kernels from booting
- Establishes chain of trust from firmware to OS
- Protects against certain rootkit attacks

### What Secure Boot Does NOT Provide
- Protection after OS boots (need disk encryption)
- Protection against physical access (need BIOS password)
- Protection against firmware vulnerabilities

## Maintenance

### After NixOS Updates
The system will automatically sign new kernels during rebuild. No manual intervention needed.

### Monitoring
Periodically check:
```bash
sudo sbctl verify
```

## Additional Notes

- Secure boot keys are persisted in `/persist/var/lib/sbctl`
- mynixos handles lanzaboote config via `my.security.secureBoot.enable = true`
- sbctl is available system-wide for debugging

## Success Criteria

✅ `sudo bootctl status` shows `Secure Boot: enabled (user)`
✅ `sudo sbctl verify` shows all UKI files are signed
✅ System boots normally without errors
✅ Windows (if dual-boot) boots with BitLocker working