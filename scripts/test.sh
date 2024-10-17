#! /bin/sh

set -e

export MIX_ENV=test
export MIX_TARGET=host

mix test
