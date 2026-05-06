//=============================================================================
// Module: diffuser
//=============================================================================
// Parameterized "Inversion About the Mean" (Grover's Diffuser)
//
// Purpose:
//   Takes an array of N probability amplitudes and performs the
//   transformation:  y[i] = (2 * average) - x[i]
//   This is the quantum diffusion operator that amplifies the marked
//   state's amplitude in Grover's search algorithm.
//
// Algorithm:
//   Step 1: Sum all N inputs          →  sum = Σ x[i]
//   Step 2: Divide sum by N           →  avg = sum / N   (right-shift for power-of-2 N)
//   Step 3: Double the average        →  two_avg = 2 * avg
//   Step 4: Compute each output       →  y[i] = two_avg - x[i]
//
// Fixed-Point Format (matches superposition_init.v):
//   Q2.14  →  16-bit signed:  1 sign + 1 integer + 14 fractional
//   1.0 is represented as 2^14 = 16384
//
// Important Design Note:
//   The implementation uses a constant divisor, so it remains synthesizable
//   for arbitrary N.
//
// Parameters:
//   N       - Number of elements (default: 4)
//   Q_TOTAL - Total fixed-point bit width (default: 16)
//   Q_FRACT - Number of fractional bits (default: 14)
//
// Ports:
//   x_in    - Flat input bus of N concatenated signed fixed-point amplitudes
//             Access element i as: x_in[i*Q_TOTAL +: Q_TOTAL]
//   y_out   - Flat output bus of N concatenated transformed amplitudes
//             Access element i as: y_out[i*Q_TOTAL +: Q_TOTAL]
//=============================================================================

module diffuser #(
    parameter N       = 4,
    parameter Q_TOTAL = 16,
    parameter Q_FRACT = 14
)(
    input  wire [N*Q_TOTAL-1:0]  x_in,    // N input amplitudes (flat bus)
    output wire [N*Q_TOTAL-1:0]  y_out    // N output amplitudes (flat bus)
);

    // =========================================================================
    // Derived parameters (computed at elaboration time)
    // =========================================================================
    // LOG2_N: used for accumulator sizing
    // SUM_WIDTH: extra bits needed so the accumulator doesn't overflow
    //   Summing N values of Q_TOTAL bits needs (Q_TOTAL + log2(N)) bits
    localparam LOG2_N    = $clog2(N);
    localparam SUM_WIDTH = Q_TOTAL + LOG2_N;

    // =========================================================================
    // Step 1: Compute the SUM of all N inputs
    // =========================================================================
    // We build a combinational adder tree using a generate block.
    // The partial sums are stored in a flat wire array.
    //
    // Tree structure for N=8:
    //   Level 0:  x[0]+x[1]   x[2]+x[3]   x[4]+x[5]   x[6]+x[7]    (4 sums)
    //   Level 1:  sum01+sum23           sum45+sum67                   (2 sums)
    //   Level 2:  sum0123 + sum4567                                   (1 sum = total)
    // =========================================================================

    // Partial sum wires: flat bus for each level
    // Each level l has (N >> (l+1)) sums, each SUM_WIDTH bits wide.
    // We allocate N entries per level (only some used) for simple indexing.
    wire signed [SUM_WIDTH-1:0] tree [0:LOG2_N*N-1];

    // Sign-extend inputs to SUM_WIDTH (flat bus)
    wire signed [SUM_WIDTH-1:0] x_ext [0:N-1];

    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : SIGN_EXTEND
            assign x_ext[k] = {{(SUM_WIDTH - Q_TOTAL){x_in[k*Q_TOTAL + Q_TOTAL - 1]}}, x_in[k*Q_TOTAL +: Q_TOTAL]};
        end
    endgenerate

    // Build the adder tree
    // tree[level*N + idx] stores partial sum at (level, idx)
    genvar level, idx;
    generate
        for (level = 0; level < LOG2_N; level = level + 1) begin : TREE_LEVEL
            for (idx = 0; idx < (N >> (level + 1)); idx = idx + 1) begin : TREE_ADD
                if (level == 0) begin : FIRST_LEVEL
                    // First level: add pairs of sign-extended inputs
                    assign tree[0*N + idx] = x_ext[2*idx] + x_ext[2*idx + 1];
                end else begin : UPPER_LEVELS
                    // Subsequent levels: add pairs from the previous level
                    assign tree[level*N + idx] = tree[(level-1)*N + 2*idx] + tree[(level-1)*N + 2*idx + 1];
                end
            end
        end
    endgenerate

    // Final sum is at tree[(LOG2_N-1)*N + 0]
    wire signed [SUM_WIDTH-1:0] total_sum;
    assign total_sum = tree[(LOG2_N - 1)*N + 0];

    // =========================================================================
    // Step 2: Compute AVERAGE = sum / N
    // =========================================================================
    // Divide by the actual N so the module works for any parameter value.
    wire signed [SUM_WIDTH-1:0] average;
    assign average = total_sum / N;

    // =========================================================================
    // Step 3: Compute 2 * AVERAGE
    // =========================================================================
    // Left shift by 1. Since amplitudes are < 1, 2*average is still < 2,
    // which fits in our Q2.14 format (range: -2.0 to +1.99994).
    wire signed [SUM_WIDTH-1:0] two_avg;
    assign two_avg = average <<< 1;          // Arithmetic left shift (signed)

    // =========================================================================
    // Step 4: Compute y[i] = (2 * average) - x[i]  for each element
    // =========================================================================
    genvar j;
    generate
        for (j = 0; j < N; j = j + 1) begin : DIFFUSE_GEN
            // Subtract in full width, then truncate back to Q_TOTAL
            wire signed [SUM_WIDTH-1:0] y_full;
            assign y_full  = two_avg - x_ext[j];
            // Truncate back to Q_TOTAL bits (keep the lower Q_TOTAL bits)
            assign y_out[j*Q_TOTAL +: Q_TOTAL] = y_full[Q_TOTAL-1:0];
        end
    endgenerate

endmodule
