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
cargo test --no-run
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --errors-for-leak-kinds=all \
         --error-exitcode=1 \
         $(find target/debug/deps -name "memory_leak_test-*" -type f -executable | head -n 1)
cd ../../../../

# 2. Sensory NIF
echo "[*] Profiling sensory_nif..."
cd app/sensory/native/sensory_nif
cargo test --no-run
# Sensory NIF might not have a dedicated memory_leak_test, so we profile the main test binary
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --errors-for-leak-kinds=all \
         --error-exitcode=1 \
         $(find target/debug/deps -name "sensory_nif-*" -type f -executable | head -n 1)
cd ../../../../

# 3. Karyon NIF
echo "[*] Profiling karyon_nif..."
cd app/native/karyon_nif
cargo test --no-run
valgrind --leak-check=full \
         --show-leak-kinds=all \
         --errors-for-leak-kinds=all \
         --error-exitcode=1 \
         $(find target/debug/deps -name "karyon_nif-*" -type f -executable | head -n 1)
cd ../../../

echo "[+] Memory Profiling Completed Successfully!"
