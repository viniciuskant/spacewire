#!/bin/sh
ROOT_DIR=$(dirname "$(readlink -f "$0")")
rm -rf "$ROOT_DIR/.tmp"
rm -rf "$ROOT_DIR/../out_data/reports/syn"/*
rm -rf "$ROOT_DIR/../out_data/pre_layout"/*

echo ">> Clean Done!"
