#!/bin/bash
set -e

echo "Compiling main.swift..."
swiftc -sdk $(xcrun --show-sdk-path --sdk macosx) main.swift -o DevPort

echo "Compilation successful. Executable created: ./DevPort"
echo "To run in background, execute: ./DevPort &"
