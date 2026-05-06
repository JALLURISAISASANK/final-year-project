//=============================================================================
// Testbench: hash_comparator_tb
//=============================================================================
// Verifies the hash_comparator module with multiple test scenarios.
//=============================================================================

`timescale 1ns / 1ps

module hash_comparator_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter N          = 4;
    parameter HASH_WIDTH = 64;

    // =========================================================================
    // Testbench signals (flat buses)
    // =========================================================================
    reg  [N*HASH_WIDTH-1:0]  input_hashes;                      // Flat: 4 x 64-bit = 256 bits
    reg  [HASH_WIDTH-1:0]    target_hash;
    wire [N-1:0]             match_result;
    wire [N*2-1:0]           oracle_phase;                       // Flat: 4 x 2-bit = 8 bits

    // =========================================================================
    // Instantiate DUT (Design Under Test)
    // =========================================================================
    hash_comparator #(
        .N(N),
        .HASH_WIDTH(HASH_WIDTH)
    ) dut (
        .input_hashes(input_hashes),
        .target_hash(target_hash),
        .match_result(match_result),
        .oracle_phase(oracle_phase)
    );

    // =========================================================================
    // Helper task: Display results
    // =========================================================================
    integer idx;
    task display_results;
        input [255:0] test_name;
        begin
            $display("");
            $display("--------------------------------------------------");
            $display("  %0s", test_name);
            $display("--------------------------------------------------");
            $display("  Target Hash:    0x%016H", target_hash);
            $display("");
            for (idx = 0; idx < N; idx = idx + 1) begin
                $display("  Hash[%0d]:  0x%016H  |  XOR = 0x%016H  |  NAND = %b",
                    idx,
                    input_hashes[idx*HASH_WIDTH +: HASH_WIDTH],
                    input_hashes[idx*HASH_WIDTH +: HASH_WIDTH] ^ target_hash,
                    match_result[idx]
                );
            end
            $display("");
            $display("  Match Result Vector: %b", match_result);
            $display("--------------------------------------------------");
        end
    endtask

    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        $display("");
        $display("==========================================================");
        $display("  HASH COMPARATOR TESTBENCH");
        $display("  N = %0d images, HASH_WIDTH = %0d bits", N, HASH_WIDTH);
        $display("==========================================================");

        // ==============================================================
        // TEST 1: One exact match (hash[2] matches target)
        // ==============================================================
        target_hash    = 64'hA3B5_C7D9_E1F2_0384;

        input_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'h1111_2222_3333_4444;  // no match
        input_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'h5555_6666_7777_8888;  // no match
        input_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'hA3B5_C7D9_E1F2_0384;  // EXACT MATCH
        input_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'hAAAA_BBBB_CCCC_DDDD;  // no match

        #10;
        display_results("TEST 1: One Exact Match (hash[2])");

        if (match_result[2] == 1'b1)
            $display("  [PASS] hash[2] correctly detected (NAND=1 for exact match)");
        else
            $display("  [FAIL] hash[2] should have NAND=1");

        // ==============================================================
        // TEST 2: No matches at all
        // ==============================================================
        target_hash = 64'hDEAD_BEEF_CAFE_BABE;

        input_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0001;
        input_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0002;
        input_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0003;
        input_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0004;

        #10;
        display_results("TEST 2: No Matches");

        // ==============================================================
        // TEST 3: Multiple matches (hash[0] and hash[3] match)
        // ==============================================================
        target_hash = 64'hFACE_B00C_1234_5678;

        input_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'hFACE_B00C_1234_5678;  // MATCH
        input_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0000;  // no match
        input_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'hFFFF_FFFF_FFFF_FFFF;  // no match
        input_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'hFACE_B00C_1234_5678;  // MATCH

        #10;
        display_results("TEST 3: Multiple Matches (hash[0] and hash[3])");

        if (match_result[0] == 1'b1 && match_result[3] == 1'b1)
            $display("  [PASS] Both matching hashes correctly detected");
        else
            $display("  [FAIL] Multiple match detection failed");

        // ==============================================================
        // TEST 4: All hashes match
        // ==============================================================
        target_hash = 64'h1234_5678_9ABC_DEF0;

        input_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'h1234_5678_9ABC_DEF0;  // MATCH
        input_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'h1234_5678_9ABC_DEF0;  // MATCH
        input_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'h1234_5678_9ABC_DEF0;  // MATCH
        input_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'h1234_5678_9ABC_DEF0;  // MATCH

        #10;
        display_results("TEST 4: All Hashes Match");

        if (match_result == 4'b1111)
            $display("  [PASS] All matches detected (match_result = 4'b1111)");
        else
            $display("  [FAIL] Expected 4'b1111, got %b", match_result);

        // ==============================================================
        // TEST 5: Bitwise complement (XOR = all 1s → NAND = 0)
        //   hash[1] = ~target → XOR = 0xFFFF...F → &(XOR)=1 → NAND=0
        //   This is the ONLY case where NAND output becomes 0.
        // ==============================================================
        target_hash = 64'h0000_FFFF_0000_FFFF;

        input_hashes[0*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_0000_0000_0001;  // random
        input_hashes[1*HASH_WIDTH +: HASH_WIDTH] = 64'hFFFF_0000_FFFF_0000;  // ~target (complement)
        input_hashes[2*HASH_WIDTH +: HASH_WIDTH] = 64'h0000_FFFF_0000_FFFF;  // EXACT MATCH
        input_hashes[3*HASH_WIDTH +: HASH_WIDTH] = 64'hAAAA_5555_AAAA_5555;  // random

        #10;
        display_results("TEST 5: Complement Test (hash[1] = ~target)");

        if (match_result[1] == 1'b0)
            $display("  [PASS] Complement gives NAND=0 (only case!)");
        else
            $display("  [FAIL] Expected NAND=0 for complement");

        if (match_result[2] == 1'b1)
            $display("  [PASS] Exact match gives NAND=1");
        else
            $display("  [FAIL] Expected NAND=1 for exact match");

        // ==============================================================
        // Final Summary
        // ==============================================================
        $display("");
        $display("==========================================================");
        $display("  ALL TESTS COMPLETED");
        $display("==========================================================");
        $display("");

        $finish;
    end

endmodule
