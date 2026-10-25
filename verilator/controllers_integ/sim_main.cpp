// Clock driver for tb_integ (controllers.sv equivalence test, CTL-2026-10-25): the SV testbench makes its own stimulus,
// checks itself and calls $finish.
#include "Vtb.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb* top = new Vtb;
    top->clk = 0;
    top->eval();
    for (vluint64_t i = 0; i < 4000000000ULL && !Verilated::gotFinish(); i++) {
        top->clk = !top->clk;
        top->eval();
    }
    int rc = Verilated::gotFinish() ? 0 : 2;
    top->final();
    delete top;
    return rc;
}
