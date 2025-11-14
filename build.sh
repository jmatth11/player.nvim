#!/usr/bin/env bash

zig_version=0.15.2
which zig
if [ $? -ne 0 ]; then
  local_arch=$(uname -m)
  mkdir /tmp/zig
  curl -o /tmp/zig/zig.tar.xz  "https://ziglang.org/download/$zig_version/zig-$local_arch-linux-$zig_version.tar.xz"
  tar -xf /tmp/zig/zig.tar.xz -C /tmp/zig/
  "/tmp/zig/zig-$local_arch-linux-$zig_version/zig" build -Doptimize=ReleaseSafe
  rm -rf /tmp/zig
else
  zig build -Doptimize=ReleaseSafe
fi
