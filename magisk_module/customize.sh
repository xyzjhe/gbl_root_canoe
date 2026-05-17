#!/system/bin/sh

# 语言选择 / Language Select
ui_print "============================================="
ui_print "  请选择语言 / Please Select Language"
ui_print "  音量上 = 中文  |  Volume UP = Chinese"
ui_print "  音量下 = 英文  |  Volume DOWN = English"
ui_print "============================================="

LANG="zh" # 默认中文
while true; do
  keyevent=$(timeout 0.5 getevent -l 2>/dev/null)
  if echo "$keyevent" | grep -q "KEY_VOLUMEUP"; then
    LANG="zh"
    ui_print "[已选择中文 / Chinese Selected]"
    break
  elif echo "$keyevent" | grep -q "KEY_VOLUMEDOWN"; then
    LANG="en"
    ui_print "[English Selected / 已选择英文]"
    break
  fi
done

# 持久化保存语言配置，给WebUI读取
ksud module config set user_lang $LANG 2>/dev/null
sleep 1

# 定义多语言文本
if [ "$LANG" = "zh" ]; then
  T_VERIFY="- 正在验证设备型号"
  T_DEVICE_OK="- 设备验证完成："
  T_PERM="- 正在设置权限"
  T_EFISP_TITLE="确保你的内核没有Baseband Guard，设备BL锁已经解锁"
  T_SOC="确保你的设备是8gen5/8elitegen5"
  T_CHECK_EXP="检测漏洞中..."
  T_INSTALL_CHOICE="请选择是否第一次安装假回锁"
  T_VOL_UP="音量上为是（全新安装，需要格式化)"
  T_VOL_DOWN="音量下为否（如果之前安装过一次假回锁或者刚刚首次安装并格式化，建议选择否）"
  T_TIP_YES="如果选择是，将会安装包含补丁的efisp 然后重启recovery 进行格式化，格式化后请安装一次这个模块来完成安装，这时选择否"
  T_TIP_NO="如果选择否，将会安装OTA更新补丁，每次OTA更新后都需要打开这个模块来安装补丁，来保留BL版本，安装完成后重启系统即可"
  T_SEL_YES="选择了是，正在安装包含补丁的efisp"
  T_NO_SLOT="无法识别当前槽位，已中止安装"
  T_PATCH_FAIL="补丁应用失败，已中止安装"
  T_NO_GBL="没有GBL漏洞，安装失败，已中止安装"
  T_SETRW_FAIL="efisp 分区设置可写失败，已中止安装"
  T_FLASH_FAIL="efisp 分区刷写失败，已中止安装"
  T_DONE_YES="安装完成，请重启到recovery进行格式化，格式化后请安装一次这个模块来完成安装，这时选择否"
  T_SEL_NO="选择了否，正在安装OTA更新模块"
  T_DONE_NO="安装完成，请重启系统即可"
else
  T_VERIFY="- Verifying device model"
  T_DEVICE_OK="- Device verified:"
  T_PERM="- Setting permissions"
  T_EFISP_TITLE="Ensure your kernel does NOT have Baseband Guard, and device BL is unlocked"
  T_SOC="Ensure your device is Snapdragon 8 Gen 5 / 8 Elite Gen 5"
  T_CHECK_EXP="Detecting exploit..."
  T_INSTALL_CHOICE="Please select if this is the FIRST installation of fake lock"
  T_VOL_UP="Volume UP = YES (Fresh install, requires format data)"
  T_VOL_DOWN="Volume DOWN = NO (If you installed fake lock before, select NO)"
  T_TIP_YES="If YES: Install patched efisp & reboot to recovery for format. After format, flash again & select NO"
  T_TIP_NO="If NO: Install OTA patch. After every OTA, re-flash to keep BL version. Reboot after install"
  T_SEL_YES="Selected YES, installing patched efisp"
  T_NO_SLOT="Failed to detect current slot, installation aborted"
  T_PATCH_FAIL="Failed to apply patch, installation aborted"
  T_NO_GBL="No GBL exploit found, installation failed"
  T_SETRW_FAIL="Failed to set efisp partition writable, installation aborted"
  T_FLASH_FAIL="Failed to flash efisp partition, installation aborted"
  T_DONE_YES="Install complete. Reboot to recovery & format data. Then re-flash & select NO"
  T_SEL_NO="Selected NO, installing OTA update patch"
  T_DONE_NO="Install complete. Please reboot your system"
fi

# 主脚本开始
ui_print "$T_VERIFY"
_model=$(getprop ro.product.model 2>/dev/null)
_name=$(getprop ro.product.name 2>/dev/null)
_incr=$(getprop ro.build.version.incremental 2>/dev/null)
ui_print "$T_DEVICE_OK $_model / $_name / $_incr"
ui_print "$T_PERM"
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644
set_perm "$MODPATH/module.prop" 0 0 0644
set_perm "$MODPATH/skip_mount" 0 0 0644
set_perm "$MODPATH/customize.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

detect_current_slot() {
  case "$(getprop ro.boot.slot_suffix 2>/dev/null)" in
    _a) printf '%s\n' '_a' ;;
    _b) printf '%s\n' '_b' ;;
    *)  return 1 ;;
  esac
}
BY_NAME_DIR="/dev/block/by-name"
RUNTIME_DIR="$MODPATH/tmp"
mkdir -p "$RUNTIME_DIR"
partition_path() { printf '%s\n' "$BY_NAME_DIR/${1}${2}"; }

ui_print "$T_EFISP_TITLE"
ui_print "$T_SOC"
ui_print "$T_CHECK_EXP"
current_slot=$(detect_current_slot 2>/dev/null)

ui_print "$T_INSTALL_CHOICE"
ui_print "$T_VOL_UP"
ui_print "$T_VOL_DOWN"
ui_print "$T_TIP_YES"
ui_print "$T_TIP_NO"

while true; do
  keyevent=$(timeout 0.5 getevent -l 2>/dev/null)
  if echo "$keyevent" | grep -q "KEY_VOLUMEUP"; then
    ui_print "$T_SEL_YES"
    if [ -z "$current_slot" ]; then
      ui_print "$T_NO_SLOT"
      abort "cannot detect current slot"
    fi
    abl_part=$(partition_path abl "$current_slot")
    $MODPATH/bin/extractfv -o "$MODPATH/tmp" -v "$abl_part" >> "$MODPATH/tmp/extract.log" 2>&1
    $MODPATH/bin/patch_abl "$MODPATH/tmp/LinuxLoader.efi" "$MODPATH/tmp/patched.efi" >> "$MODPATH/tmp/patch.log" 2>&1
    if [ ! -f "$MODPATH/tmp/patched.efi" ]; then
      ui_print "$T_PATCH_FAIL"
      abort "patch failed"
    fi
    if grep -q "Warning: Failed to patch ABL GBL" "$RUNTIME_DIR/patch.log"; then
      ui_print "$T_NO_GBL"
      abort "no exploit"
    fi
    if ! blockdev --setrw "/dev/block/by-name/efisp" >> "$MODPATH/tmp/flash.log" 2>&1; then
      ui_print "$T_SETRW_FAIL"
      abort "setrw failed"
    fi
    if ! dd if="$MODPATH/tmp/patched.efi" of=/dev/block/by-name/efisp bs=4M conv=fsync >> "$MODPATH/tmp/flash.log" 2>&1; then
      ui_print "$T_FLASH_FAIL"
      abort "flash failed"
    fi
    sync
    ui_print "$T_DONE_YES"
    rm -rf "$RUNTIME_DIR"
    break
  elif echo "$keyevent" | grep -q "KEY_VOLUMEDOWN"; then
    ui_print "$T_SEL_NO"
    ui_print "$T_DONE_NO"
    rm -rf "$RUNTIME_DIR"
    break
  fi
done
