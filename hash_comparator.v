//=============================================================================
// Module: hash_comparator
//=============================================================================
// Parameterized Hash Comparison Module for Image Matching (Oracle)
//
// Purpose:
//   Compares N input image hashes against a single target hash using
//   bitwise XNOR followed by AND reduction, then computes the quantum
//   oracle phase marker: 1 - (2 * match_result).
//
// How it works (for each image i):
//   1. XNOR:         xnor_result[i] = ~(input_hashes[i] ^ target_hash)  (64-bit)
//   2. AND reduction: match_result[i] = &xnor_result[i]                  (1-bit)
//                     → 1 if ALL bits match, 0 otherwise
//   3. Oracle phase:  oracle_phase[i] = 1 - (2 * match_result[i])        (signed)
//                     → +1 if no match,  -1 if match (phase flip)
//
// Parameters:
//   N          - Number of input images (default: 4)
//   HASH_WIDTH - Width of each hash in bits (default: 64)
//
// Ports:
//   input_hashes  - Flat bus of N concatenated hashes (N*HASH_WIDTH bits)
//                   Access hash i as: input_hashes[i*HASH_WIDTH +: HASH_WIDTH]
//   target_hash   - The target hash to compare against (HASH_WIDTH bits)
//   match_result  - N-bit vector: 1 = match, 0 = no match
//   oracle_phase  - Flat bus of N concatenated signed 2-bit values: +1 or -1
//                   Access phase i as: oracle_phase[i*2 +: 2]
//=============================================================================

module hash_comparator #(
    parameter N          = 4,       // Number of input images
    parameter HASH_WIDTH = 64       // Width of each hash (64-bit = 16 hex digits)
)(
    input  wire [N*HASH_WIDTH-1:0]      input_hashes,            // Flat: N x HASH_WIDTH-bit hashes
    input  wire [HASH_WIDTH-1:0]        target_hash,             // Single target hash
    output wire [N-1:0]                 match_result,            // N-bit match vector
    output wire [N*2-1:0]               oracle_phase             // Flat: N x 2-bit signed phases
);

    // =========================================================================
    // Internal wires for XNOR results (flat bus)
    // =========================================================================
    wire [N*HASH_WIDTH-1:0] xnor_result;

    // =========================================================================
    // Generate block: XNOR + AND reduction + oracle phase for each hash
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : HASH_COMPARE_GEN

            // ----------------------------------------------------------
            // Step 1: Bitwise XNOR between input_hashes[i] and target_hash
            //         XNOR gives 1 for each matching bit, 0 for mismatch
            // ----------------------------------------------------------
            assign xnor_result[i*HASH_WIDTH +: HASH_WIDTH] = ~(input_hashes[i*HASH_WIDTH +: HASH_WIDTH] ^ target_hash);

            // ----------------------------------------------------------
            // Step 2: AND reduction — all 64 bits must be 1 (full match)
            //         match_result[i] = 1 when hashes are identical
            // ----------------------------------------------------------
            assign match_result[i] = &xnor_result[i*HASH_WIDTH +: HASH_WIDTH];

            // ----------------------------------------------------------
            // Step 3: Oracle phase = 1 - (2 * match_result[i])
            //
            //   match_result = 0  →  1 - 0  = +1  (2'sb01)  no phase flip
            //   match_result = 1  →  1 - 2  = -1  (2'sb11)  phase flip!
            //
            //   In 2-bit signed: +1 = 2'b01, -1 = 2'b11
            //   This is simply:  oracle_phase = match_result ? -1 : +1
            // ----------------------------------------------------------
            assign oracle_phase[i*2 +: 2] = match_result[i] ? -2'sd1 : 2'sd1;

        end
    endgenerate

endmodule
