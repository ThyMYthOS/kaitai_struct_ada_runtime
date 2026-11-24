#!/bin/sh
# Run a program built for an STM32F4 (Cortex-M4) in the Renode simulator.
#
#   renode-run.sh <elf> [seconds]
#
# Prints what the program writes to its console, followed by a line
# "INSTRUCTIONS <n>" with the number of instructions executed.  The program
# is expected to print a line "DONE" when it has finished; if it does not
# within the given virtual time (default 0.5 s), the script fails.
#
# RENODE_HOME names the directory of a portable Renode installation.
set -eu

RENODE_HOME=${RENODE_HOME:-$HOME/.local/share/renode}
elf=$(realpath "$1")
seconds=${2:-0.5}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The platform description shipped with Renode downloads a register
# description that is only used to name registers in the log.  Drop it, so
# that the run works without network access, and add the semihosting console
# a light run-time library prints to.  An embedded run-time library prints
# to USART1 instead.
sed '/ApplySVD/d' "$RENODE_HOME/platforms/cpus/stm32f4.repl" >"$work/stm32f4.repl"
printf '\nuartSemihosting: UART.SemihostingUart @ cpu\n' >>"$work/stm32f4.repl"

cat >"$work/run.resc" <<RESC
mach create
machine LoadPlatformDescription @$work/stm32f4.repl
sysbus LoadELF @$elf
sysbus.cpu.uartSemihosting CreateFileBackend @$work/semihosting.log true
sysbus.usart1 CreateFileBackend @$work/usart1.log true
emulation RunFor "$seconds"
sysbus.cpu ExecutedInstructions
quit
RESC

count=$("$RENODE_HOME/renode" --disable-gui --plain --console "$work/run.resc" 2>&1 |
   grep -o '^0x[0-9A-Fa-f]*' | tail -n 1)

cat "$work/semihosting.log" "$work/usart1.log" 2>/dev/null | tr -d '\r' >"$work/console.log" || true
cat "$work/console.log"

if ! grep -q '^DONE' "$work/console.log"; then
   echo "renode-run: $1 did not print DONE" >&2
   exit 1
fi
echo "INSTRUCTIONS $((count))"
