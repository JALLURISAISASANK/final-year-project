//=============================================================================
// Module: superposition_init
//=============================================================================
// Parameterized Initializer for Quantum State Amplitudes
//
// Purpose:
//   Initializes an array of N probability amplitudes for Grover's search.
//   The initial state is a uniform superposition, where each state has
//   an amplitude of 1/sqrt(N).
//
// Fixed-Point Representation:
//   Since Verilog does not support floating-point synthesis natively, we use
//   a signed fixed-point format (default Q2.14):
//   - 1 Sign bit
//   - 1 Integer bit
//   - 14 Fractional bits
//   Total = 16 bits.
//   In Q2.14, 1.0 is represented as (1 << 14) = 16384.
//
// Implementation Details:
//   The 1/sqrt(N) value is computed at elaboration time using an integer
//   square-root approximation, so the module remains synthesizable while
//   supporting arbitrary N.
//
// Parameters:
//   N          - Number of images / states (default: 4)
//   Q_TOTAL    - Total bits for the fixed-point number (default: 16)
//   Q_FRACT    - Fractional bits for the fixed-point number (default: 14)
//   INIT_AMP   - The initial amplitude, optionally overridden by the user.
//                Defaults to the compile-time 1/sqrt(N) approximation.
//
// Ports:
//   amplitudes - Flat output bus of N concatenated fixed-point amplitudes
//                Access element i as: amplitudes[i*Q_TOTAL +: Q_TOTAL]
//=============================================================================

module superposition_init #(
    parameter N       = 4,
    parameter Q_TOTAL = 16,
    parameter Q_FRACT = 14,
    // By default, compute the init amplitude at elaboration time
    parameter signed [Q_TOTAL-1:0] INIT_AMP = compute_init_amp(N)
)(
    output wire [N*Q_TOTAL-1:0] amplitudes
);

    // =========================================================================
    // Compile-Time integer sqrt helper
    // =========================================================================
    // Uses the standard shift/subtract square-root algorithm.
    // The result is floor(sqrt(value)).
    function integer integer_sqrt;
        input integer value;
        integer op;
        integer res;
        integer one;
        begin
            op = value;
            res = 0;
            one = 1 << 30;

            while (one > op)
                one = one >> 2;

            while (one != 0) begin
                if (op >= res + one) begin
                    op  = op - (res + one);
                    res = (res >> 1) + one;
                end else begin
                    res = res >> 1;
                end
                one = one >> 2;
            end

            integer_sqrt = res;
        end
    endfunction

    // =========================================================================
    // Compile-Time approximation for 1/sqrt(N)
    // =========================================================================
    // The result is scaled to Q_TOTAL/Q_FRACT fixed-point format.
    function signed [Q_TOTAL-1:0] compute_init_amp;
        input integer target_n;
        integer one_in_q;
        integer root_scaled;
        begin
            one_in_q = (1 << Q_FRACT); // Representation of 1.0

            if (target_n <= 1) begin
                compute_init_amp = one_in_q;
            end else begin
                // Scale the square-root by 256 before taking the reciprocal.
                // This gives a tighter integer approximation than using floor(sqrt(N)).
                root_scaled = integer_sqrt(target_n << 16);
                if (root_scaled <= 0) begin
                    compute_init_amp = 0;
                end else begin
                    compute_init_amp = ((1 << (Q_FRACT + 8)) / root_scaled);
                end
            end
        end
    endfunction

    // =========================================================================
    // Generate Block: Fan-out the constant to all N outputs
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : AMP_GEN
            // This instantiates a simple routing of the constant value
            // to each of the N array indices
            assign amplitudes[i*Q_TOTAL +: Q_TOTAL] = INIT_AMP;
        end
    endgenerate

endmodule
