#!/usr/bin/env bash
set -ex

ROOT="."

# install
bore_cmd="bore"
if ! which bore > /dev/null; then
  echo "bore not found!"
  wget https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
  tar xvzf bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
  bore_cmd="./bore"
fi

# start and check endpoint
$bore_cmd local --local-host core --to bore.pub 8088
$bore_cmd local --local-host optout --to bore.pub 8081

