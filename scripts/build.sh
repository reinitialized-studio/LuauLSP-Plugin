#!/usr/bin/env bash
set -e
rojo serve default.project.json \
  & rojo sourcemap default.project.json -o sourcemap.json --watch