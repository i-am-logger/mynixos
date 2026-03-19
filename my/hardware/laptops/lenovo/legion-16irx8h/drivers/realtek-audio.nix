{ pkgs, ... }:

{
  # Realtek ALC3287 + TAS2781 speaker amp driver configuration
  # Lenovo Legion Pro 7 16IRX8H specific

  # The TAS2781 speaker amp has a V1 CRC error in its UEFI calibration data.
  # The amp works fine with default calibration after an I2C device reset.
  # We unbind/rebind the I2C device to reinitialize, then force firmware load.
  systemd.services.fix-audio-speaker = {
    description = "Fix TAS2781 Speaker Amp (Legion hardware fix)";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" "pipewire.service" "wireplumber.service" ];
    wants = [ "pipewire.service" ];
    script = ''
      # Unbind and rebind the TAS2781 I2C device to reinitialize the amp
      echo "i2c-TIAS2781:00" > /sys/bus/i2c/drivers/tas2781-hda/unbind || true
      sleep 1
      echo "i2c-TIAS2781:00" > /sys/bus/i2c/drivers/tas2781-hda/bind || true
      sleep 1
      # Force firmware load and unmute speaker
      ${pkgs.alsa-utils}/bin/amixer -c 0 cset iface=CARD,name='Speaker Force Firmware Load' on || true
      ${pkgs.alsa-utils}/bin/amixer -c 0 sset "Speaker" unmute || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
