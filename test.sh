#! /bin/bash

set -e
set -u

nimble server
tests/rosencrantz &
PID="$!"
nimble client
kill "$PID"