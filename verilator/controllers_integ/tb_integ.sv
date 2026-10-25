// tb_integ: controllers.sv equivalence test (CTL-2026-10-25, wave 2). Generic; the core's blocks come from gen.py.
//   dut = new_in  (live top level's input block on the v2 library, real pause_cpu)
//   raw = old_in  (pre-integration block, verbatim from the backup)
//   mdl = oldm_in (old block + every intended-difference patch: the spec of what may change)
//   m_<C> = old block + the patch of class C only (used to attribute each difference to its class)
// Every checked cycle: dut must equal mdl on every output bit (FAIL otherwise). Each cycle where dut != raw is counted
// under the class(es) whose patch changes those bits; a differing bit no class explains is a FAIL (UNEXPLAINED).
// Config 0 has no keyboard events and no pause: dut must equal raw exactly, except classes marked exact_ok (pad-2 Start).
// Stimulus: random pad bits (both pads), PS/2 key events (the core's codes + random codes, random extended bit),
// analog sticks around the core's thresholds, random pause windows, random status / xin (per-game ids etc.).
// Defines: CFGS (configurations), CYC (checked cycles per configuration), BREAK (flip one dut bit once: must FAIL 1).
`ifndef CFGS
 `define CFGS 4
`endif
`ifndef CYC
 `define CYC 1000000
`endif
module tb_integ(input clk);
reg  [15:0] joystick_0 = 16'd0, joystick_1 = 16'd0;
reg  [15:0] joystick_analog_0 = 16'd0, joystick_analog_1 = 16'd0, joystick_r_analog_0 = 16'd0, joystick_r_analog_1 = 16'd0;
reg  [10:0] ps2_key = 11'd0;
reg         pause_cpu = 1'b0, vblank = 1'b0;
reg [127:0] status = 128'd0;
reg  [63:0] xin = 64'd0;

`include "tb_cfg.svh"

localparam int WARM = 64;
longint cyc = 0, checked = 0, fail_s = 0, fail_u = 0, fail_x = 0, ndiff = 0, chg = 0, kev = 0, pclk = 0;
longint ncls[NCLS];
int     cfg = -1, vcnt = 0, vper = 1000;
bit     kb_en = 0, p_en = 0, brk_done = 0;
reg [31:0] r, r2;
reg [OW-1:0] od, d, expl, prev = '0;

function automatic [7:0] axis(input [31:0] q);
    int t;
    begin
        t = thr[q[19:16] % NTHR];
        case (q[3:0])
            4'd0, 4'd1: axis = 8'd0;
            4'd2: axis = 8'(t - 1);   4'd3: axis = 8'(t);   4'd4: axis = 8'(t + 1);
            4'd5: axis = 8'(-t - 1);  4'd6: axis = 8'(-t);  4'd7: axis = 8'(-t + 1);
            4'd8: axis = 8'h7F;       4'd9: axis = 8'h80;   4'd10: axis = 8'h81;
            default: axis = q[15:8];
        endcase
    end
endfunction

task automatic new_config();
    cfg++;
    kb_en = (cfg != 0);
    p_en  = (cfg >= 2);
    pause_cpu = 1'b0;
    r = $urandom; r2 = $urandom; status = {r, r2, ~r, r ^ r2};
    r = $urandom; r2 = $urandom; xin = {r, r2};
    r = $urandom; vper = 800 + int'(r[9:0]);
    for (int i = 0; i < NCLS; i++) ncls[i] = ncls[i];
    $display("  config %0d: keyboard %0d, pause %0d, status[31:0] %h, xin %h", cfg, kb_en, p_en, status[31:0], xin);
endtask

initial for (int i = 0; i < NCLS; i++) ncls[i] = 0;

always @(negedge clk) begin
    // ---------------- check (outputs settled after the last posedge)
    if (cfg >= 0 && (cyc % (WARM + `CYC)) > WARM) begin
        checked++;
        od = o_dut;
        if (od !== prev) chg++;
        prev = od;
`ifdef BREAK
        if (!brk_done && cfg == `CFGS - 1 && (cyc % (WARM + `CYC)) > `CYC / 2) begin
            od[0] = ~od[0]; brk_done = 1; $display("  BREAK applied @%0d", cyc);
        end
`endif
        if (od !== o_all) begin
            fail_s++;
            if (fail_s <= 10) $display("  FAIL(strict) @%0d cfg %0d: dut %h model %h raw %h", cyc, cfg, od, o_all, o_raw);
        end
        d = od ^ o_raw;
        if (d != '0) begin
            ndiff++;
            expl = '0;
            for (int i = 0; i < NCLS; i++) if ((d & (o_raw ^ o_cls[i])) != '0) begin ncls[i]++; expl = expl | (o_raw ^ o_cls[i]); end
            if ((d & ~expl) != '0) begin
                fail_u++;
                if (fail_u <= 10) $display("  FAIL(unexplained) @%0d cfg %0d: dut %h raw %h bits %h", cyc, cfg, od, o_raw, d & ~expl);
            end
            if (cfg == 0) begin
                expl = '0;
                for (int i = 0; i < NCLS; i++) if (exact_ok[i]) expl = expl | (o_raw ^ o_cls[i]);
                if ((d & ~expl) != '0) begin
                    fail_x++;
                    if (fail_x <= 10) $display("  FAIL(exact cfg 0) @%0d: dut %h raw %h", cyc, od, o_raw);
                end
            end
        end
    end
    // ---------------- stimulus
    cyc++;
    if (cyc % (WARM + `CYC) == 1) begin
        if (cfg + 1 == `CFGS) begin
            $display("RESULT tb_integ: configs %0d, checked cycles %0d, FAIL strict %0d, FAIL unexplained %0d, FAIL exact %0d",
                     `CFGS, checked, fail_s, fail_u, fail_x);
            $display("  outputs changed on %0d checked cycles; %0d key events; %0d paused clocks", chg, kev, pclk);
            $display("  cycles where new != old: %0d", ndiff);
            for (int i = 0; i < NCLS; i++) $display("    class %s: %0d cycles", cls_name[i], ncls[i]);
            $finish;
        end
        else new_config();
    end
    r = $urandom;
    if (r[4:0] == 5'd0)   joystick_0[r[11:8]]  = ~joystick_0[r[11:8]];
    if (r[20:16] == 5'd0) joystick_1[r[27:24]] = ~joystick_1[r[27:24]];
    r = $urandom; r2 = $urandom;
    if (r[5:0] == 6'd0) begin
        case (r[7:6])
            2'd0: joystick_r_analog_0[(r[8] ? 8 : 0) +: 8] = axis(r2);
            2'd1: joystick_r_analog_1[(r[8] ? 8 : 0) +: 8] = axis(r2);
            2'd2: joystick_analog_0[(r[8] ? 8 : 0) +: 8]   = axis(r2);
            2'd3: joystick_analog_1[(r[8] ? 8 : 0) +: 8]   = axis(r2);
        endcase
    end
    r = $urandom; r2 = $urandom;
    if (kb_en && r[5:0] == 6'd0) begin
        kev++;
        ps2_key = {~ps2_key[10], r2[0], r2[2:1] == 2'd0, (r2[7:4] == 4'd0) ? r2[15:8] : codes[r2[23:16] % NCODES]};
    end
    r = $urandom;
    if (r[12:0] == 13'd0) begin r2 = $urandom; xin[r[18:13]] = r2[0]; xin[r[24:19]] = r2[1]; end
    if (r[31:20] == 12'd0) begin r2 = $urandom; status[r2[6:0]] = ~status[r2[6:0]]; end
    r = $urandom;
    if (p_en && r[9:0] == 10'd0) pause_cpu = ~pause_cpu;
    if (pause_cpu) pclk++;
    vcnt = (vcnt + 1 >= vper) ? 0 : vcnt + 1;
    vblank = vcnt < vper / 8;
end

endmodule
