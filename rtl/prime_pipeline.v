// =============================================================================
// FILE        : prime_pipeline.v
// TITLE       : 5-Stage Pipelined Prime Number Detection Processor
// DESCRIPTION : Detects whether two input numbers are prime using a 5-stage
//               pipeline: IF -> ID -> EX -> MEM -> WB
//               Tool: Cadence NCLaunch + SimVision
//
// PIPELINE STAGES:
//   Stage 1 (IF)  - Instruction Fetch   : Load number A and B into pipeline
//   Stage 2 (ID)  - Instruction Decode  : Decode operand, init divisor counter
//   Stage 3 (EX)  - Execute             : Modulo/division trial division check
//   Stage 4 (MEM) - Memory / Accumulate : Accumulate factor count
//   Stage 5 (WB)  - Write Back          : Assert is_prime output (toggle to 1)
//
// OUTPUT:
//   is_prime_A = 1 if number A is prime, else 0
//   is_prime_B = 1 if number B is prime, else 0
//
// AUTHOR      : Pipeline Architecture Design
// =============================================================================

`timescale 1ns / 1ps

module prime_pipeline (
    input  wire        clk,
    input  wire        rst,          // Active-high synchronous reset
    input  wire [7:0]  num_A,        // First  input number (8-bit, 2-255)
    input  wire [7:0]  num_B,        // Second input number (8-bit, 2-255)
    input  wire        start,        // Pulse high for 1 clk to begin processing

    output reg         is_prime_A,   // 1 = prime, 0 = not prime (toggles to 1)
    output reg         is_prime_B,   // 1 = prime, 0 = not prime (toggles to 1)
    output reg         valid_out,    // Result valid flag
    output reg [2:0]   stage_dbg     // Current pipeline stage indicator (debug)
);

// =============================================================================
// PARAMETERS
// =============================================================================
localparam IDLE  = 3'd0;
localparam ST_IF = 3'd1;   // Stage 1: Instruction Fetch
localparam ST_ID = 3'd2;   // Stage 2: Instruction Decode
localparam ST_EX = 3'd3;   // Stage 3: Execute (trial division)
localparam ST_MM = 3'd4;   // Stage 4: Memory / Accumulate
localparam ST_WB = 3'd5;   // Stage 5: Write Back

// =============================================================================
// PIPELINE REGISTERS — Stage 1 (IF) outputs
// =============================================================================
reg [7:0]  if_numA, if_numB;
reg        if_valid;

// =============================================================================
// PIPELINE REGISTERS — Stage 2 (ID) outputs
// =============================================================================
reg [7:0]  id_numA,    id_numB;
reg [7:0]  id_divisor; // Divisor starts at 2 for trial division
reg        id_valid;

// =============================================================================
// PIPELINE REGISTERS — Stage 3 (EX) outputs
// =============================================================================
reg [7:0]  ex_numA,     ex_numB;
reg        ex_divA_ok,  ex_divB_ok; // 1 = current divisor does NOT divide numX
reg [7:0]  ex_divisor;
reg        ex_valid;

// =============================================================================
// PIPELINE REGISTERS — Stage 4 (MEM) outputs
// =============================================================================
reg [7:0]  mem_numA,   mem_numB;
reg [7:0]  mem_cntA;   // Number of divisors found for A (should be 0 for prime)
reg [7:0]  mem_cntB;   // Number of divisors found for B
reg        mem_valid;

// =============================================================================
// INTERNAL SIGNALS FOR TRIAL DIVISION ENGINE
// =============================================================================
// The execute stage iterates divisor from 2 to (num/2).
// We use a FSM-based multi-cycle approach latched per pipeline clock.

reg [2:0]  state;

// Trial division working registers
reg [7:0]  work_numA, work_numB;
reg [7:0]  divisor;
reg [7:0]  factcnt_A, factcnt_B;  // factor count accumulators
reg [7:0]  half_A, half_B;        // num/2 upper bound for trial division
reg        trial_done;

// Modulo computation wires
wire [7:0] mod_A = work_numA % divisor;
wire [7:0] mod_B = work_numB % divisor;

// =============================================================================
// STAGE DEBUG OUTPUT
// =============================================================================
always @(*) begin
    stage_dbg = state;
end

// =============================================================================
// MAIN FSM + PIPELINE DATAPATH
// =============================================================================
always @(posedge clk) begin
    if (rst) begin
        // ---- Reset all pipeline registers and outputs ----
        state       <= IDLE;
        valid_out   <= 1'b0;
        is_prime_A  <= 1'b0;
        is_prime_B  <= 1'b0;
        trial_done  <= 1'b0;

        if_numA  <= 8'd0; if_numB  <= 8'd0; if_valid  <= 1'b0;
        id_numA  <= 8'd0; id_numB  <= 8'd0; id_valid  <= 1'b0;
        ex_numA  <= 8'd0; ex_numB  <= 8'd0; ex_valid  <= 1'b0;
        mem_numA <= 8'd0; mem_numB <= 8'd0; mem_valid <= 1'b0;

        divisor   <= 8'd2;
        factcnt_A <= 8'd0;
        factcnt_B <= 8'd0;
        id_divisor<= 8'd2;
        work_numA <= 8'd0;
        work_numB <= 8'd0;
        half_A    <= 8'd0;
        half_B    <= 8'd0;

        ex_divA_ok  <= 1'b0;
        ex_divB_ok  <= 1'b0;
        ex_divisor  <= 8'd2;
        mem_cntA    <= 8'd0;
        mem_cntB    <= 8'd0;

    end else begin

        case (state)

            // ------------------------------------------------------------------
            // IDLE — Wait for start pulse
            // ------------------------------------------------------------------
            IDLE: begin
                valid_out  <= 1'b0;
                is_prime_A <= 1'b0;
                is_prime_B <= 1'b0;
                if_valid   <= 1'b0;
                if (start) begin
                    state <= ST_IF;
                end
            end

            // ------------------------------------------------------------------
            // STAGE 1: INSTRUCTION FETCH (IF)
            //   - Capture input numbers into pipeline
            //   - Drive stage_dbg = 1
            // ------------------------------------------------------------------
            ST_IF: begin
                // Latch inputs into IF pipeline register
                if_numA  <= num_A;
                if_numB  <= num_B;
                if_valid <= 1'b1;
                valid_out<= 1'b0;

                // Advance to decode stage
                state <= ST_ID;

                // Inform simVision: IF stage active
                // (visible in waveform as stage_dbg == 1)
            end

            // ------------------------------------------------------------------
            // STAGE 2: INSTRUCTION DECODE (ID)
            //   - Pass numbers forward
            //   - Initialise divisor = 2 (smallest possible prime factor)
            //   - Compute num/2 bounds for trial division
            // ------------------------------------------------------------------
            ST_ID: begin
                id_numA    <= if_numA;
                id_numB    <= if_numB;
                id_divisor <= 8'd2;        // Start trial from divisor = 2
                id_valid   <= if_valid;

                // Pre-compute upper bound (num >> 1 == num/2) for EX stage
                half_A     <= if_numA >> 1;
                half_B     <= if_numB >> 1;

                // Seed working registers for execute stage
                work_numA  <= if_numA;
                work_numB  <= if_numB;
                divisor    <= 8'd2;
                factcnt_A  <= 8'd0;
                factcnt_B  <= 8'd0;

                state      <= ST_EX;
            end

            // ------------------------------------------------------------------
            // STAGE 3: EXECUTE (EX)  — TRIAL DIVISION LOOP
            //   - Iterates divisor from 2 to (num/2)
            //   - For each divisor: check (num % divisor == 0)
            //   - Counts factors; stays in EX until all divisors checked
            //   - Moves to MEM when trial division complete
            // ------------------------------------------------------------------
            ST_EX: begin
                ex_numA   <= work_numA;
                ex_numB   <= work_numB;
                ex_valid  <= id_valid;

                if (divisor <= half_A || divisor <= half_B) begin
                    // ----- Check divisibility for Number A -----
                    if (divisor <= half_A) begin
                        if (mod_A == 8'd0) begin
                            // divisor divides numA → numA is NOT prime
                            factcnt_A <= factcnt_A + 8'd1;
                        end
                    end

                    // ----- Check divisibility for Number B -----
                    if (divisor <= half_B) begin
                        if (mod_B == 8'd0) begin
                            // divisor divides numB → numB is NOT prime
                            factcnt_B <= factcnt_B + 8'd1;
                        end
                    end

                    // Increment divisor for next cycle iteration
                    divisor   <= divisor + 8'd1;

                    // Expose current divisor to waveform via ex_divisor
                    ex_divisor <= divisor;

                    // Stay in EX stage until both checks complete
                    state <= ST_EX;

                end else begin
                    // All divisors checked → pass factors to MEM stage
                    ex_divA_ok <= (factcnt_A == 8'd0) ? 1'b1 : 1'b0;
                    ex_divB_ok <= (factcnt_B == 8'd0) ? 1'b1 : 1'b0;
                    ex_divisor <= divisor;
                    state      <= ST_MM;
                end
            end

            // ------------------------------------------------------------------
            // STAGE 4: MEMORY / ACCUMULATE (MEM)
            //   - Latch factor counts from execute stage
            //   - Determine primality: prime iff factcnt == 0
            //   - Special case: numbers < 2 are NOT prime
            // ------------------------------------------------------------------
            ST_MM: begin
                mem_numA  <= ex_numA;
                mem_numB  <= ex_numB;
                mem_valid <= ex_valid;

                // Accumulate results (factor count from EX)
                mem_cntA  <= factcnt_A;
                mem_cntB  <= factcnt_B;

                state <= ST_WB;
            end

            // ------------------------------------------------------------------
            // STAGE 5: WRITE BACK (WB)
            //   - Write final prime/non-prime result to output ports
            //   - is_prime_X TOGGLES to 1 if prime, remains/sets 0 if not
            //   - Assert valid_out
            // ------------------------------------------------------------------
            ST_WB: begin
                // --- Number A primality decision ---
                // Special cases: 0 and 1 are NOT prime; 2 is prime
                if (mem_numA < 8'd2) begin
                    is_prime_A <= 1'b0;
                end else if (mem_numA == 8'd2) begin
                    is_prime_A <= 1'b1;   // 2 is prime (toggle to 1)
                end else begin
                    // Prime iff no factors found in EX stage
                    is_prime_A <= (mem_cntA == 8'd0) ? 1'b1 : 1'b0;
                end

                // --- Number B primality decision ---
                if (mem_numB < 8'd2) begin
                    is_prime_B <= 1'b0;
                end else if (mem_numB == 8'd2) begin
                    is_prime_B <= 1'b1;   // 2 is prime
                end else begin
                    is_prime_B <= (mem_cntB == 8'd0) ? 1'b1 : 1'b0;
                end

                // Assert result valid — visible in SimVision waveform
                valid_out <= 1'b1;

                // Return to IDLE; ready for next pair
                state <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule
// =============================================================================
// END OF FILE: prime_pipeline.v
// =============================================================================
