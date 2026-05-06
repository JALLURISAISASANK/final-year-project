//=============================================================================
// Testbench: grovers_top_wind_tb
//=============================================================================
// Verifies end-to-end behavior of grovers_top using the wind_turbine hashes.
// Each test case uses N=16 image hashes with one exact target hash.
//=============================================================================

`timescale 1ns / 1ps

module grovers_top_wind_tb;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    parameter N          = 16;
    parameter HASH_WIDTH = 64;
    parameter Q_TOTAL    = 16;
    parameter Q_FRACT    = 14;

    // Derived widths
    localparam integer INDEX_WIDTH = (N < 2) ? 1 : $clog2(N);

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------
    reg  [N*HASH_WIDTH-1:0] image_hashes;
    reg  [HASH_WIDTH-1:0]   target_hash;

    wire [N-1:0]            oracle_marked;
    wire [N*Q_TOTAL-1:0]    final_amplitudes;
    wire [$clog2(N)-1:0]    match_index;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    grovers_top #(
        .N(N),
        .HASH_WIDTH(HASH_WIDTH),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) dut (
        .image_hashes(image_hashes),
        .target_hash(target_hash),
        .oracle_marked(oracle_marked),
        .final_amplitudes(final_amplitudes),
        .match_index(match_index)
    );

    // ------------------------------------------------------------------------
    // Utility for printing fixed-point values as real
    // ------------------------------------------------------------------------
    function real q_to_real;
        input signed [Q_TOTAL-1:0] q_val;
        begin
            q_to_real = $itor(q_val) / $itor(1 << Q_FRACT);
        end
    endfunction

    integer i;
    integer j;
    reg test_pass;
    task print_state;
        input [8*64-1:0] label;
        begin
            $display("");
            $display("------------------------------------------------------------");
            $display("%0s", label);
            $display("target_hash = 0x%016H", target_hash);
            $display("oracle_marked = %b, match_index = %0d", oracle_marked, match_index);
            for (i = 0; i < N; i = i + 1) begin
                $display("img[%0d] = 0x%016H | amp[%0d] = %6d (0x%04X) ~ %f",
                         i,
                         image_hashes[i*HASH_WIDTH +: HASH_WIDTH],
                         i,
                         $signed(final_amplitudes[i*Q_TOTAL +: Q_TOTAL]),
                         final_amplitudes[i*Q_TOTAL +: Q_TOTAL],
                         q_to_real($signed(final_amplitudes[i*Q_TOTAL +: Q_TOTAL])));
            end
        end
    endtask

    task load_base_hashes;
        begin
            image_hashes[0*HASH_WIDTH +: HASH_WIDTH]  = 64'h91384F479D6C5663;
            image_hashes[1*HASH_WIDTH +: HASH_WIDTH]  = 64'h99D5269DC9360B35;
            image_hashes[2*HASH_WIDTH +: HASH_WIDTH]  = 64'h9BA33B4C5C166EA8;
            image_hashes[3*HASH_WIDTH +: HASH_WIDTH]  = 64'hD9B3266499996666;
            image_hashes[4*HASH_WIDTH +: HASH_WIDTH]  = 64'hD93366889C236F99;
            image_hashes[5*HASH_WIDTH +: HASH_WIDTH]  = 64'hB5B0733E04969B39;
            image_hashes[6*HASH_WIDTH +: HASH_WIDTH]  = 64'h9B9266E4D9C8E466;
            image_hashes[7*HASH_WIDTH +: HASH_WIDTH]  = 64'hA6C3D18AF9074BC2;
            image_hashes[8*HASH_WIDTH +: HASH_WIDTH]  = 64'hD973668C9B3229CC;
            image_hashes[9*HASH_WIDTH +: HASH_WIDTH]  = 64'h99334ACC9C6277E1;
            image_hashes[10*HASH_WIDTH +: HASH_WIDTH] = 64'h9993666D99D2360B;
            image_hashes[11*HASH_WIDTH +: HASH_WIDTH] = 64'hC13A9F78E2B44D10;
            image_hashes[12*HASH_WIDTH +: HASH_WIDTH] = 64'hD907E21FC81E6339;
            image_hashes[13*HASH_WIDTH +: HASH_WIDTH] = 64'hAE3472C78A4B29B5;
            image_hashes[14*HASH_WIDTH +: HASH_WIDTH] = 64'hC8F03B24D4DF1754;
            image_hashes[15*HASH_WIDTH +: HASH_WIDTH] = 64'h7D11EA309BC45F62;
        end
    endtask

    task check_single_match;
        input [8*64-1:0] test_name;
        input [N-1:0] expected_mask;
        input integer expected_index;
        reg signed [Q_TOTAL-1:0] expected_amp;
        reg signed [Q_TOTAL-1:0] candidate_amp;
        begin
            test_pass = 1'b1;

            if (oracle_marked !== expected_mask)
                test_pass = 1'b0;

            if (match_index !== expected_index[INDEX_WIDTH-1:0])
                test_pass = 1'b0;

            expected_amp = $signed(final_amplitudes[expected_index*Q_TOTAL +: Q_TOTAL]);
            for (j = 0; j < N; j = j + 1) begin
                if (j != expected_index) begin
                    candidate_amp = $signed(final_amplitudes[j*Q_TOTAL +: Q_TOTAL]);
                    if (expected_amp <= candidate_amp)
                        test_pass = 1'b0;
                end
            end

            if (test_pass)
                $display("[PASS] %0s", test_name);
            else
                $display("[FAIL] %0s", test_name);
        end
    endtask

    // ------------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------------
    initial begin
        $display("");
        $display("============================================================");
        $display("GROVERS_TOP WIND-TURBINE TESTBENCH");
        $display("N=%0d HASH_WIDTH=%0d Q=%0d.%0d", N, HASH_WIDTH, Q_TOTAL-Q_FRACT, Q_FRACT);
        $display("============================================================");

        // ================================================================
        // TEST 1: Single exact match at index 0 (N=16)
        // ================================================================
        target_hash = 64'h871F33A769499A38;
        load_base_hashes();
        image_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'h871F33A769499A38; // match

        #10;
        print_state("TEST 1: single match at index 0");
        check_single_match("TEST 1", 16'h0001, 0);

        // ================================================================
        // TEST 2: Single exact match at index 1 (N=16)
        // ================================================================
        target_hash = 64'h871F33A769499A38;
        load_base_hashes();
        image_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'h871F33A769499A38; // match

        #10;
        print_state("TEST 2: single match at index 1");
        check_single_match("TEST 2", 16'h0002, 1);

        // ================================================================
        // TEST 3: Single exact match at index 2 (N=16)
        // ================================================================
        target_hash = 64'h876739D84CB3915A;
        load_base_hashes();
        image_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'h876739D84CB3915A; // match

        #10;
        print_state("TEST 3: single match at index 2");
        check_single_match("TEST 3", 16'h0004, 2);

        // ================================================================
        // TEST 4: Single exact match at index 3 (N=16)
        // ================================================================
        target_hash = 64'h9951E02EC6F371D4;
        load_base_hashes();
        image_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'h9951E02EC6F371D4; // match

        #10;
        print_state("TEST 4: single match at index 3");
        check_single_match("TEST 4", 16'h0008, 3);

        $display("");
        $display("============================================================");
        $display("GROVERS_TOP_WIND_TB COMPLETE");
        $display("============================================================");

        $finish;
    end

endmodule