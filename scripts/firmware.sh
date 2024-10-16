#! /bin/sh

set -e

export MIX_ENV=prod
export MIX_TARGET=rpi0
export HOST=silvia.local

MIX_TARGET=host mix do deps.get, assets.deploy
mix deps.get
mix firmware
