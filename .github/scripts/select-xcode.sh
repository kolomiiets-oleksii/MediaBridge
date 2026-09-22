#!/bin/bash
set -euo pipefail

wanted_swift_version="$1"

swift_version_of() {
  local developer_dir="$1"
  local driver="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  [ -x "$driver" ] || return 0
  DEVELOPER_DIR="$developer_dir" "$driver" --version 2>/dev/null |
    sed -n 's/.*Apple Swift version \([0-9][0-9.]*\).*/\1/p'
}

for app in $(ls -d /Applications/Xcode*.app | sort -V); do
  developer_dir="$app/Contents/Developer"
  case "$(swift_version_of "$developer_dir")" in
    "$wanted_swift_version"|"$wanted_swift_version".*) selected="$developer_dir" ;;
  esac
done

if [ -z "${selected:-}" ]; then
  echo "::error::No installed Xcode provides Swift $wanted_swift_version"
  for app in $(ls -d /Applications/Xcode*.app | sort -V); do
    echo "$app -> $(swift_version_of "$app/Contents/Developer")"
  done
  exit 1
fi

sudo xcode-select -s "$selected"
swift --version
