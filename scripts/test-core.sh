#!/usr/bin/env bash
# Run SidelineCore tests. Works with full Xcode or with only the Command Line
# Tools (where swift-testing's framework path must be passed explicitly).
set -euo pipefail
cd "$(dirname "$0")/../packages/SidelineCore"
FLAGS=()
if ! xcode-select -p | grep -q Xcode.app; then
  CLT=/Library/Developer/CommandLineTools/Library/Developer
  FLAGS=(-Xswiftc -F -Xswiftc "$CLT/Frameworks"
         -Xlinker -F -Xlinker "$CLT/Frameworks"
         -Xlinker -rpath -Xlinker "$CLT/Frameworks"
         -Xlinker -rpath -Xlinker "$CLT/usr/lib")
fi
swift test ${FLAGS[@]+"${FLAGS[@]}"} "$@"
