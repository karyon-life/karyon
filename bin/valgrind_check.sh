#!/bin/bash
# Karyon NIF Memory Profiling Script
# This script runs the Rust test suites under Valgrind to check for memory leaks.

set -e

# check if valgrind is installed
if ! command -v valgrind &> /dev/null
then
    echo "[!] Valgrind could not be found. Please install it to run memory profiling."
    echo "    On Ubuntu/Debian: sudo apt install valgrind"
    exit 1
fi

echo "[*] Starting Memory Profiling for Karyon NIFs..."

# 1. Rhizome NIF
echo "[*] Profiling rhizome_nif..."
cd app/rhizome/native/rhizome_nif
cargo build
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --errors-for-leak-kinds=all \
         --error-exitcode=1 \
         target/debug/deps/memory_leak_test-*
cd ../../../../

# 2. Sensory NIF
echo "[*] Profiling sensory_nif..."
cd app/sensory/native/sensory_nif
cargo build
# We run the unit tests under valgrind
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --errors-for-leak-kinds=all \
         --error-exitcode=1 \
         target/debug/deps/sensory_nif-*
cd ../../../../

echo "[+] Memory Profiling Completed Successfully!"
