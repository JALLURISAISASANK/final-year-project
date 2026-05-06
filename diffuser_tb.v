//=============================================================================
// Testbench: diffuser_tb
//=============================================================================
// Verifies the diffuser module (inversion about the mean) using known
// values that can be hand-calculated for verification.
//
// Test Case (N=4, Q2.14 fixed-point):
//   Suppose after the oracle marks state[2], the amplitudes are:
//     x[0] =  0.5    (uniform)
//     x[1] =  0.5    (uniform)
//     x[2] = -0.5    (phase-flipped by oracle)
//     x[3] =  0.5    (uniform)
//
//   Average = (0.5 + 0.5 + (-0.5) + 0.5) / 4 = 1.0 / 4 = 0.25
//   2 * Average = 0.5
//
//   y[0] = 0.5 - 0.5  =  0.0
//   y[1] = 0.5 - 0.5  =  0.0
//   y[2] = 0.5 - (-0.5) = 1.0   ← AMPLIFIED!
//   y[3] = 0.5 - 0.5  =  0.0
//
//   After 1 iteration: target state has amplitude 1.0, probability 100%!
//=============================================================================

`timescale 1ns / 1ps

module diffuser_tb;

    // =========================================================================
    // Parameters (matching superposition_init.v)
    // =========================================================================
    parameter N       = 4;
    parameter Q_TOTAL = 16;
    parameter Q_FRACT = 14;

    // Fixed-point constants
    localparam signed [Q_TOTAL-1:0] POS_HALF = 16'sd8192;   // +0.5 in Q2.14
    localparam signed [Q_TOTAL-1:0] NEG_HALF = -16'sd8192;  // -0.5 in Q2.14
    localparam signed [Q_TOTAL-1:0] ONE      = 16'sd16384;  // +1.0 in Q2.14
    localparam signed [Q_TOTAL-1:0] ZERO     = 16'sd0;      //  0.0 in Q2.14

    // =========================================================================
    // Signals (flat buses)
    // =========================================================================
    reg  [N*Q_TOTAL-1:0] x_in;
    wire [N*Q_TOTAL-1:0] y_out;

    // =========================================================================
    // DUT
    // =========================================================================
    diffuser #(
        .N(N),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) dut (
        .x_in(x_in),
        .y_out(y_out)
    );

    // =========================================================================
    // Helper functions: Convert Q2.14 to real for display
    // =========================================================================
    integer idx;

    task display_array;
        input [255:0] label;
        begin
            $display("  %0s:", label);
            for (idx = 0; idx < N; idx = idx + 1) begin
                // Display: index, raw fixed-point, hex, approximate real value
                $display("    [%0d] = %6d (0x%04X)  ~  %f",
                    idx,
                    $signed(x_in[idx*Q_TOTAL +: Q_TOTAL]),
                    x_in[idx*Q_TOTAL +: Q_TOTAL],
                    $itor($signed(x_in[idx*Q_TOTAL +: Q_TOTAL])) / $itor(1 << Q_FRACT)
                );
            end
        end
    endtask

    task display_output;
        begin
            $display("  Output y_out:");
            for (idx = 0; idx < N; idx = idx + 1) begin
                $display("    [%0d] = %6d (0x%04X)  ~  %f",
                    idx,
                    $signed(y_out[idx*Q_TOTAL +: Q_TOTAL]),
                    y_out[idx*Q_TOTAL +: Q_TOTAL],
                    $itor($signed(y_out[idx*Q_TOTAL +: Q_TOTAL])) / $itor(1 << Q_FRACT)
                );
            end
        end
    endtask

    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        $display("");
        $display("==========================================================");
        $display("  DIFFUSER (INVERSION ABOUT THE MEAN) TESTBENCH");
        $display("  N = %0d,  Fixed-Point: Q%0d.%0d", N, Q_TOTAL-Q_FRACT, Q_FRACT);
        $display("  1.0 = %0d,  0.5 = %0d", ONE, POS_HALF);
        $display("==========================================================");

        // ==============================================================
        // TEST 1: After oracle marks state[2]
        //   x = [+0.5, +0.5, -0.5, +0.5]
        //   Expected: y = [0, 0, +1.0, 0]
        // ==============================================================
        $display("");
        $display("--------------------------------------------------");
        $display("  TEST 1: Oracle marked state[2]");
        $display("--------------------------------------------------");

        x_in[0*Q_TOTAL +: Q_TOTAL] = POS_HALF;    //  +0.5
        x_in[1*Q_TOTAL +: Q_TOTAL] = POS_HALF;    //  +0.5
        x_in[2*Q_TOTAL +: Q_TOTAL] = NEG_HALF;    //  -0.5  (oracle flipped this)
        x_in[3*Q_TOTAL +: Q_TOTAL] = POS_HALF;    //  +0.5

        #10;

        display_array("Input x_in");
        $display("");
        display_output();
        $display("");

        // Verify
        if ($signed(y_out[2*Q_TOTAL +: Q_TOTAL]) == ONE && 
            $signed(y_out[0*Q_TOTAL +: Q_TOTAL]) == ZERO && 
            $signed(y_out[1*Q_TOTAL +: Q_TOTAL]) == ZERO && 
            $signed(y_out[3*Q_TOTAL +: Q_TOTAL]) == ZERO)
            $display("  [PASS] Target state amplified to 1.0, others zeroed out!");
        else begin
            $display("  [CHECKING] y_out[0]=%0d (expect %0d)", $signed(y_out[0*Q_TOTAL +: Q_TOTAL]), ZERO);
            $display("  [CHECKING] y_out[1]=%0d (expect %0d)", $signed(y_out[1*Q_TOTAL +: Q_TOTAL]), ZERO);
            $display("  [CHECKING] y_out[2]=%0d (expect %0d)", $signed(y_out[2*Q_TOTAL +: Q_TOTAL]), ONE);
            $display("  [CHECKING] y_out[3]=%0d (expect %0d)", $signed(y_out[3*Q_TOTAL +: Q_TOTAL]), ZERO);
        end

        // ==============================================================
        // TEST 2: All uniform (no oracle applied yet)
        //   x = [+0.5, +0.5, +0.5, +0.5]
        //   avg = 0.5, 2*avg = 1.0
        //   y[i] = 1.0 - 0.5 = 0.5 for all
        //   Expected: output equals input (identity when uniform)
        // ==============================================================
        $display("");
        $display("--------------------------------------------------");
        $display("  TEST 2: All uniform (no oracle)");
        $display("--------------------------------------------------");

        x_in[0*Q_TOTAL +: Q_TOTAL] = POS_HALF;
        x_in[1*Q_TOTAL +: Q_TOTAL] = POS_HALF;
        x_in[2*Q_TOTAL +: Q_TOTAL] = POS_HALF;
        x_in[3*Q_TOTAL +: Q_TOTAL] = POS_HALF;

        #10;

        display_array("Input x_in");
        $display("");
        display_output();
        $display("");

        if ($signed(y_out[0*Q_TOTAL +: Q_TOTAL]) == POS_HALF && 
            $signed(y_out[1*Q_TOTAL +: Q_TOTAL]) == POS_HALF &&
            $signed(y_out[2*Q_TOTAL +: Q_TOTAL]) == POS_HALF && 
            $signed(y_out[3*Q_TOTAL +: Q_TOTAL]) == POS_HALF)
            $display("  [PASS] Uniform input is preserved (identity operation)!");
        else
            $display("  [FAIL] Uniform input should remain unchanged.");

        // ==============================================================
        // TEST 3: Oracle marks state[0]
        //   x = [-0.5, +0.5, +0.5, +0.5]
        //   avg = 0.5/4 = 0.25, 2*avg = 0.5
        //   y[0] = 0.5 - (-0.5) = 1.0   ← AMPLIFIED!
        //   y[1] = 0.5 - 0.5    = 0.0
        //   y[2] = 0.5 - 0.5    = 0.0
        //   y[3] = 0.5 - 0.5    = 0.0
        // ==============================================================
        $display("");
        $display("--------------------------------------------------");
        $display("  TEST 3: Oracle marked state[0]");
        $display("--------------------------------------------------");

        x_in[0*Q_TOTAL +: Q_TOTAL] = NEG_HALF;    // -0.5 (oracle flipped)
        x_in[1*Q_TOTAL +: Q_TOTAL] = POS_HALF;    // +0.5
        x_in[2*Q_TOTAL +: Q_TOTAL] = POS_HALF;    // +0.5
        x_in[3*Q_TOTAL +: Q_TOTAL] = POS_HALF;    // +0.5

        #10;

        display_array("Input x_in");
        $display("");
        display_output();
        $display("");

        if ($signed(y_out[0*Q_TOTAL +: Q_TOTAL]) == ONE)
            $display("  [PASS] State[0] amplified to 1.0!");
        else
            $display("  [FAIL] Expected y_out[0] = %0d, got %0d", ONE, $signed(y_out[0*Q_TOTAL +: Q_TOTAL]));

        // ==============================================================
        // Final Summary
        // ==============================================================
        $display("");
        $display("==========================================================");
        $display("  ALL DIFFUSER TESTS COMPLETED");
        $display("==========================================================");
        $display("");

        $finish;
    end

endmodule
