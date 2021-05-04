#!/usr/bin/env bash
# exit on error
set -o errexit

_build/prod/rel/fset/bin/fset eval "Fset.Release.migrate"
_build/prod/rel/fset/bin/fset start
