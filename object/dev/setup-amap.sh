#!/bin/sh
# Official static SDKs. No global installation, account access or IDFA framework.
set -eu
cd "$(dirname "$0")/../ios"
root="$PWD/.build/AMap"
mkdir -p "$root/downloads"
fetch() {
  name="$1" url="$2" digest="$3"
  archive="$root/downloads/$name.zip"
  if [ ! -f "$archive" ]; then curl -fL "$url" -o "$archive"; fi
  actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
  if [ "$actual" != "$digest" ]; then echo "SDK checksum mismatch: $name" >&2; exit 1; fi
  unzip -qo "$archive" -d "$root"
}
fetch navigation https://a.amap.com/lbs/static/zip/AMap_iOS_Navi_Lib_V11.3.100.zip b6704b432c0b6f9618c8e60d5ac82123b1715ea601bf8e1e0432057836713930
fetch foundation https://a.amap.com/lbs/static/zip/AMap_iOS_Foundation_NO_IDFA_Lib_V1.9.4.zip e812db2c83e2542e8bcd1d6904e03d49fa1a2e20b33772e1c3f1ede14d5dd552
fetch location https://amappc.oss-cn-zhangjiakou.aliyuncs.com/lbs/static/zip/AMap_iOS_Loc_Lib_V2.12.2.zip 1a62b65b55a2a5a5fcc645cf7afa8509bc74e5490b25548e08be8aac714bce26
fetch search https://a.amap.com/lbs/static/zip/AMap_iOS_Search_Lib_V9.8.1.zip d11e0b418319c74abf5228611f678b58130eac791e267d6d6e3e7ec9f41b2007
fetch privacy-foundation https://a.amap.com/lbs/static/zip/AMapFoundationKit-NO-IDFA.xcprivacy.zip 45d16718a40cc00d6845a6b8e2d98ec6793bf16df57cca75eac838dec6d15f6c
fetch privacy-location https://a.amap.com/lbs/static/zip/AMapLocationKit.xcprivacy.zip f7c2de72785b966a73df79ea4b7c696132fa411cd89cf36e56dd7428400ea5c8
fetch privacy-navigation https://a.amap.com/lbs/static/zip/AMapNaviKit.xcprivacy.zip 16ed40f7fbf982ebc1302ecf858650575a659ba0c6ec18197a3472343266edd2
fetch privacy-search https://a.amap.com/lbs/static/zip/AMapSearchKit.xcprivacy.zip abbd5a0fa0ca13c2f2b9e247b549a03a55b66e5e8cade345f797c63ab99c24c3
for component in Foundation Location Navi Search; do
  mkdir -p "$root/AMap${component}Privacy.bundle"
  manifest="$root/AMap${component}Kit.xcprivacy"
  if [ "$component" = Foundation ]; then manifest="$root/AMapFoundationKit-NO-IDFA.xcprivacy"; fi
  cp "$manifest" "$root/AMap${component}Privacy.bundle/PrivacyInfo.xcprivacy"
done
printf '%s\n'  'AMap SDKs restored: Navi 11.3.100, Foundation No-IDFA 1.9.4, Location 2.12.2, Search 9.8.1'
