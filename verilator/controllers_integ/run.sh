#!/bin/bash
# controllers.sv equivalence test (CTL-2026-10-25, wave 2): old = pre-integration input block (old_in.sv, from the backup),
# new = the live top level's block (new_in.sv, regenerated here) on the core's rtl/mister_custom/controllers.sv.
#   ./run.sh            regenerate new_in.sv, build in a fresh obj dir, run (CFGS x CYC checked cycles)
#   ./run.sh break      same with one dut output bit flipped once: must report FAIL strict 1
# Rebuild the old files: python3 -B -I gen.py . --old <backup of the original top level>
set -u
cd "$(dirname "$0")" && cd "$(pwd -P)"
ulimit -v 8000000
V=$(command -v verilator)
OBJ=$(realpath -m "${OBJ:-obj}")
LIB=$(realpath ../../rtl/mister_custom/controllers.sv)
python3 -B -I gen.py . >/dev/null || { echo "gen.py failed"; exit 1; }
B=""; n=tb_integ
if [ "${1:-}" = "break" ]; then B="+define+BREAK=1"; n=tb_integ_break; fi
n=$n.$(date +%Y%m%d_%H%M%S_%N); mkdir -p "$OBJ"        # always a fresh build dir
OLDS=$(ls "$PWD"/old*_in.sv)
$V --cc --exe --build -O2 -j 4 -Wno-fatal -Wno-lint -Wno-style ${DEFS:-} $B --top-module tb_integ --prefix Vtb -I"$PWD" \
   -Mdir "$OBJ/$n" "$PWD/tb_integ.sv" "$PWD/new_in.sv" $OLDS "$LIB" "$PWD/sim_main.cpp" > "$OBJ/$n.build.log" 2>&1 \
   || { echo "BUILD FAIL (see $OBJ/$n.build.log)"; tail -30 "$OBJ/$n.build.log"; exit 1; }
time "$OBJ/$n/Vtb"
