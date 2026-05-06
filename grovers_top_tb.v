`timescale 1ns / 1ps

module grovers_top_tb;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    parameter N          = 128;
    parameter HASH_WIDTH = 64;
    parameter Q_TOTAL    = 12;
    parameter Q_FRACT    = 10;

    // ------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------------
    reg                     clk;
    reg                     reset;
    reg                     start;
    reg  [HASH_WIDTH-1:0]   target_hash;
    wire                    done;
    wire [$clog2(N)-1:0]    match_index;
    wire                    found;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    grovers_top #(
        .N(N),
        .HASH_WIDTH(HASH_WIDTH),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .target_hash(target_hash),
        .done(done),
        .match_index(match_index),
        .found(found)
    );

    // ------------------------------------------------------------------------
    // Clock Generation (100 MHz)
    // ------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------------
    initial begin
        // Initialize
        reset = 1;
        start = 0;
        target_hash = 64'h0;
        
        $display("");
        $display("============================================================");
        $display("GROVERS_TOP TESTBENCH (N=%0d, Sequential FSM)", N);
        $display("============================================================");

        // De-assert reset
        #20;
        reset = 0;
        #10;

        // TEST 1: Match for vegetable_greenhouse_00003.jpg (index 2)
        $display("TEST 1: Searching for hash 0xFF44447D7FC0C068 (expected index 2)");
        target_hash = 64'hFF44447D7FC0C068;
        start = 1;
        #10;
        start = 0;
        wait(done == 1'b1);
        #5;
        if (match_index == 2 && found == 1'b1)
            $display("[PASS] TEST 1: Correctly found at index 2 with found=1");
        else
            $display("[FAIL] TEST 1: Found at %0d, expected 2, found=%b", match_index, found);
        #20;

        // TEST 2: Match for wetland_00019.jpg (index 42)
        $display("");
        $display("TEST 2: Searching for hash 0xE7B1CDB4A34B3160 (expected index 42)");
        target_hash = 64'hE7B1CDB4A34B3160;
        start = 1;
        #10;
        start = 0;
        wait(done == 1'b1);
        #5;
        if (match_index == 42 && found == 1'b1)
            $display("[PASS] TEST 2: Correctly found at index 42 with found=1");
        else
            $display("[FAIL] TEST 2: Found at %0d, expected 42, found=%b", match_index, found);
        #20;

        // TEST 3: Match for wind_turbine_00506.jpg (index 1023)
        $display("");
        $display("TEST 3: Searching for hash 0x9912BDDDE9A0D162 (expected index 1023)");
        target_hash = 64'h9912BDDDE9A0D162;
        start = 1;
        #10;
        start = 0;
        wait(done == 1'b1);
        #5;
        if (match_index == 1023 && found == 1'b1)
            $display("[PASS] TEST 3: Correctly found at index 1023 with found=1");
        else
            $display("[FAIL] TEST 3: Found at %0d, expected 1023, found=%b", match_index, found);
        #20;

        // TEST 4: No match (all zeros)
        $display("");
        $display("TEST 4: Searching for non-existent hash 0x00...0");
        target_hash = 64'h0;
        start = 1;
        #10;
        start = 0;
        wait(done == 1'b1);
        #5;
        $display("       Match index defaults to %0d due to uniform amplitudes", match_index);
        if (found == 1'b0)
            $display("[PASS] TEST 4: found signal is correctly 0");
        else
            $display("[FAIL] TEST 4: found signal is %b, expected 0", found);
        
        $display("");
        $display("============================================================");
        $display("GROVERS_TOP_TB COMPLETE");
        $display("============================================================");

        $finish;
    end

endmodule
