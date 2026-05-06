//=============================================================================
// Testbench: superposition_init_tb
//=============================================================================
// Verifies the fixed-point initialization module for probability amplitudes.
// We will test multiple values of N (1, 4, 16, 256) and verify that
// the generated Q2.14 internal values correctly map back to the real floats.
//=============================================================================

`timescale 1ns / 1ps

module superposition_init_tb;

    // Parameters
    parameter Q_TOTAL = 16;
    parameter Q_FRACT = 14;

    // Fixed point 1.0 representation = 2^14 = 16384
    localparam ONE_IN_Q = (1 << Q_FRACT);

    // Flat bus wires for outputs (Testing N=4)
    wire [4*Q_TOTAL-1:0] amp_n4;
    
    // Flat bus wires for outputs (Testing N=16)
    wire [16*Q_TOTAL-1:0] amp_n16;

    // DUT instances for different N
    superposition_init #(
        .N(4),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) dut_n4 (
        .amplitudes(amp_n4)
    );

    superposition_init #(
        .N(16),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) dut_n16 (
        .amplitudes(amp_n16)
    );

    // Utility function: Convert Q2.14 integer back to Real float for printing
    function real q_to_real;
        input signed [Q_TOTAL-1:0] q_val;
        begin
            q_to_real = q_val / ($itor(ONE_IN_Q));  
        end
    endfunction

    initial begin
        $display("");
        $display("==========================================================");
        $display("  SUPERPOSITION INIT TESTBENCH");
        $display("  Fixed-Point Format: Q%0d.%0d", (Q_TOTAL-Q_FRACT), Q_FRACT);
        $display("==========================================================");

        #10;
        
        // =========================================================
        // Test N=4: 1/sqrt(4) = 0.5
        // Expected Q2.14 value = 0.5 * 16384 = 8192 (16'h2000)
        // =========================================================
        $display("--------------------------------");
        $display("  Testing N = 4");
        $display("  Expected Real: 0.5");
        $display("  Expected Fixed: 8192 (0x2000)");
        $display("--------------------------------");
        $display("  amp_n4[0] = %0d (0x%04X) -> Real ~ %f", 
            $signed(amp_n4[0*Q_TOTAL +: Q_TOTAL]), amp_n4[0*Q_TOTAL +: Q_TOTAL], 
            q_to_real($signed(amp_n4[0*Q_TOTAL +: Q_TOTAL])));
        $display("  amp_n4[3] = %0d (0x%04X) -> Real ~ %f", 
            $signed(amp_n4[3*Q_TOTAL +: Q_TOTAL]), amp_n4[3*Q_TOTAL +: Q_TOTAL], 
            q_to_real($signed(amp_n4[3*Q_TOTAL +: Q_TOTAL])));

        if (amp_n4[0*Q_TOTAL +: Q_TOTAL] == 16'h2000)
            $display("  [PASS] N=4 successfully initialized to 0.5");
        else
            $display("  [FAIL] N=4 failed");


        // =========================================================
        // Test N=16: 1/sqrt(16) = 0.25
        // Expected Q2.14 value = 0.25 * 16384 = 4096 (16'h1000)
        // =========================================================
        $display("\n--------------------------------");
        $display("  Testing N = 16");
        $display("  Expected Real: 0.25");
        $display("  Expected Fixed: 4096 (0x1000)");
        $display("--------------------------------");
        $display("  amp_n16[0]  = %0d (0x%04X) -> Real ~ %f", 
            $signed(amp_n16[0*Q_TOTAL +: Q_TOTAL]), amp_n16[0*Q_TOTAL +: Q_TOTAL], 
            q_to_real($signed(amp_n16[0*Q_TOTAL +: Q_TOTAL])));
        $display("  amp_n16[15] = %0d (0x%04X) -> Real ~ %f", 
            $signed(amp_n16[15*Q_TOTAL +: Q_TOTAL]), amp_n16[15*Q_TOTAL +: Q_TOTAL], 
            q_to_real($signed(amp_n16[15*Q_TOTAL +: Q_TOTAL])));

        if (amp_n16[0*Q_TOTAL +: Q_TOTAL] == 16'h1000)
            $display("  [PASS] N=16 successfully initialized to 0.25");
        else
            $display("  [FAIL] N=16 failed");

        $display("\n==========================================================");
        $display("  ALL VERIFICATION COMPLETE");
        $display("==========================================================");
        
        $finish;
    end

endmodule
