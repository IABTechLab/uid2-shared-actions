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

$bore_cmd server > $ROOT/bore_server.out 2>&1 &
until [ -f $ROOT/bore_server.out ]
do
  sleep 5
done
cat $ROOT/bore_server.out
BORE_SERVER=$(cat $ROOT/bore_server.out | grep addr | cut -d '=' -f2 | cut -d ':' -f1)

$bore_cmd local --to $BORE_SERVER 5001  > $ROOT/bore_localhost.out 2>&1 &
$bore_cmd local --to $BORE_SERVER 8088  > $ROOT/bore_core.out 2>&1 &
$bore_cmd local --to $BORE_SERVER 8081 > $ROOT/bore_optout.out 2>&1 &

until [ -f $ROOT/bore_localhost.out ] && [ -f $ROOT/bore_core.out ] && [ -f $ROOT/bore_optout.out ]
do
  sleep 5
done

cat $ROOT/bore_localhost.out
cat $ROOT/bore_core.out
cat $ROOT/bore_optout.out

BORE_URL_LOCALSTACK=$(cat $ROOT/bore_localhost.out | grep at | cut -d ' ' -f7)
BORE_URL_CORE=$(cat $ROOT/bore_core.out | grep at | cut -d ' ' -f7)
BORE_URL_OPTOUT=$(cat $ROOT/bore_optout.out | grep at | cut -d ' ' -f7)

# export to Github output
echo "BORE_URL_LOCALSTACK=$BORE_URL_LOCALSTACK"
echo "BORE_URL_CORE=$BORE_URL_CORE"
echo "BORE_URL_OPTOUT=$BORE_URL_OPTOUT"

if [ -z "$GITHUB_OUTPUT" ]; then
  echo "not in github action"
else
  echo "BORE_URL_LOCALSTACK=$BORE_URL_LOCALSTACK" >> $GITHUB_OUTPUT
  echo "BORE_URL_CORE=$BORE_URL_CORE" >> $GITHUB_OUTPUT
  echo "BORE_URL_OPTOUT=$BORE_URL_OPTOUT" >> $GITHUB_OUTPUT
fi


