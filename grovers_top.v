`timescale 1ns / 1ps
//=============================================================================
// Module: grovers_top
//=============================================================================
// Parameterized Grover search top-level for image-hash matching.
//
// Ports use flat buses so the design remains Verilog-2001 friendly:
//   image_hashes[i]   -> image_hashes[i*HASH_WIDTH +: HASH_WIDTH]
//   amplitudes[i]     -> amplitudes[i*Q_TOTAL +: Q_TOTAL]
//=============================================================================

module grovers_top #(
    parameter N          = 128,
    parameter HASH_WIDTH = 64,
    parameter Q_TOTAL    = 12,
    parameter Q_FRACT    = 10
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    start,
    input  wire [HASH_WIDTH-1:0]   target_hash,
    output reg                     done,
    output reg  [(N < 2 ? 1 : $clog2(N))-1:0] match_index,
    output wire found
);

    // =============================================================
    // Internal wires that were previously outputs
    // =============================================================
    wire [N-1:0]            oracle_marked;
    reg  [N*Q_TOTAL-1:0]    current_amplitudes;

    // =============================================================
    // Internal Image Hashes ROM
    // =============================================================
    wire [N*HASH_WIDTH-1:0] image_hashes;
    reg  [HASH_WIDTH-1:0]   hash_rom [0:N-1];

    initial begin
        $readmemh("C:/Users/jsnss/OneDrive/Desktop/vivvado/final_year_project/hashes.mem", hash_rom);
    end

    genvar h_idx;
    generate
        for (h_idx = 0; h_idx < N; h_idx = h_idx + 1) begin : HASH_FLATTEN
            assign image_hashes[h_idx*HASH_WIDTH +: HASH_WIDTH] = hash_rom[h_idx];
        end
    endgenerate

    // =============================================================
    // Local parameters and helper functions
    // =============================================================
    localparam integer INDEX_WIDTH = (N < 2) ? 1 : $clog2(N);
    localparam integer GROVER_ITERATIONS = compute_grover_iterations(N);

    // Integer square root using the standard shift/subtract algorithm.
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

    // Compute floor(pi/4 * sqrt(N)) using an integer approximation.
    function integer compute_grover_iterations;
        input integer target_n;
        integer root_scaled;
        begin
            if (target_n <= 1) begin
                compute_grover_iterations = 0;
            end else begin
                // sqrt(target_n) scaled by 256, then multiplied by pi/4.
                root_scaled = integer_sqrt(target_n << 16);
                compute_grover_iterations = (root_scaled * 7854) / 2560000;

                // Ensure at least one iteration for any multi-state search.
                if (compute_grover_iterations < 1)
                    compute_grover_iterations = 1;
            end
        end
    endfunction

    // =============================================================
    // Oracle comparator output
    // =============================================================
    wire [N-1:0]     match_result;
    wire [N*2-1:0]   oracle_phase;

    hash_comparator #(
        .N(N),
        .HASH_WIDTH(HASH_WIDTH)
    ) u_hash_comparator (
        .input_hashes(image_hashes),
        .target_hash(target_hash),
        .match_result(match_result),
        .oracle_phase(oracle_phase)
    );

    assign oracle_marked = match_result;

    // =============================================================
    // Initial uniform superposition
    // =============================================================
    wire [N*Q_TOTAL-1:0] initial_amplitudes;

    superposition_init #(
        .N(N),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) u_superposition_init (
        .amplitudes(initial_amplitudes)
    );

    // =============================================================
    // Grover iteration pipeline (Sequential FSM)
    // =============================================================
    
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_COMPUTE = 2'd1;
    localparam STATE_DONE    = 2'd2;

    reg [1:0] state;
    reg [(GROVER_ITERATIONS > 1 ? $clog2(GROVER_ITERATIONS) : 1)-1:0] iter_counter;

    // Single combinational pipeline stage
    wire [N*Q_TOTAL-1:0] oracle_state;
    wire [N*Q_TOTAL-1:0] diffused_state;

    genvar element;
    generate
        for (element = 0; element < N; element = element + 1) begin : ORACLE_PHASE_INVERSION
            assign oracle_state[element*Q_TOTAL +: Q_TOTAL] =
                oracle_marked[element]
                    ? -$signed(current_amplitudes[element*Q_TOTAL +: Q_TOTAL])
                    : current_amplitudes[element*Q_TOTAL +: Q_TOTAL];
        end
    endgenerate

    diffuser #(
        .N(N),
        .Q_TOTAL(Q_TOTAL),
        .Q_FRACT(Q_FRACT)
    ) u_diffuser (
        .x_in(oracle_state),
        .y_out(diffused_state)
    );

    // FSM sequential logic
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            iter_counter <= 0;
            current_amplitudes <= { (N*Q_TOTAL) {1'b0} };
            done <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (GROVER_ITERATIONS == 0) begin
                            current_amplitudes <= initial_amplitudes;
                            state <= STATE_DONE;
                        end else begin
                            current_amplitudes <= initial_amplitudes;
                            iter_counter <= 0;
                            state <= STATE_COMPUTE;
                        end
                    end
                end

                STATE_COMPUTE: begin
                    current_amplitudes <= diffused_state;
                    if (iter_counter == GROVER_ITERATIONS - 1) begin
                        state <= STATE_DONE;
                    end else begin
                        iter_counter <= iter_counter + 1;
                    end
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= STATE_IDLE;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

    // =============================================================
    // Best-match index: choose the largest final amplitude.
    // =============================================================
    integer idx;
    reg signed [Q_TOTAL-1:0] current_amp;
    reg signed [Q_TOTAL-1:0] best_amp;

    always @* begin
        match_index = {INDEX_WIDTH{1'b0}};
        best_amp = $signed(current_amplitudes[0*Q_TOTAL +: Q_TOTAL]);

        for (idx = 1; idx < N; idx = idx + 1) begin
            current_amp = $signed(current_amplitudes[idx*Q_TOTAL +: Q_TOTAL]);
            if (current_amp > best_amp) begin
                best_amp = current_amp;
                match_index = idx;
            end
        end
    end

    // =============================================================
    // Classical verification of the measurement result
    // =============================================================
    assign found = (target_hash == hash_rom[match_index]);

endmodule
