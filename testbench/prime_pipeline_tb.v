// =============================================================================
// FILE        : tb_prime_pipeline.v
// TITLE       : Testbench — 5-Stage Pipelined Prime Number Detection
//
// *** IMPROVED VERSION ***
//   - NO expected flags needed. Just give the two numbers.
//   - The hardware computes and prints the result by itself.
//   - To test your own numbers: only edit the apply_test lines at the bottom.
//   - apply_test syntax:  apply_test(8'd<numA>, 8'd<numB>);
//
// Tool : Cadence NCLaunch + SimVision
// =============================================================================

`timescale 1ns / 1ps

module tb_prime_pipeline;

// =============================================================================
// DUT PORT SIGNALS
// =============================================================================
reg        clk;
reg        rst;
reg [7:0]  num_A;
reg [7:0]  num_B;
reg        start;

wire       is_prime_A;
wire       is_prime_B;
wire       valid_out;
wire [2:0] stage_dbg;

// =============================================================================
// INSTANTIATE DUT
// =============================================================================
prime_pipeline DUT (
    .clk        (clk),
    .rst        (rst),
    .num_A      (num_A),
    .num_B      (num_B),
    .start      (start),
    .is_prime_A (is_prime_A),
    .is_prime_B (is_prime_B),
    .valid_out  (valid_out),
    .stage_dbg  (stage_dbg)
);

// =============================================================================
// CLOCK — 10 ns period (100 MHz)
// =============================================================================
initial clk = 1'b0;
always #5 clk = ~clk;

// =============================================================================
// STAGE NAME TASK — for readable transcript
// =============================================================================
task print_stage;
    input [2:0] s;
    case (s)
        3'd0: $write("IDLE");
        3'd1: $write("IF  ");
        3'd2: $write("ID  ");
        3'd3: $write("EX  ");
        3'd4: $write("MEM ");
        3'd5: $write("WB  ");
        default: $write("??? ");
    endcase
endtask

// =============================================================================
// APPLY_TEST TASK
//   Just pass two numbers. Hardware computes. Result printed automatically.
//   NO expected answer needed from you.
//
//   Usage: apply_test(8'd<your_number_A>, 8'd<your_number_B>);
// =============================================================================
task apply_test;
    input [7:0] a, b;
    begin
        // --- Drive inputs ---
        @(negedge clk);
        num_A = a;
        num_B = b;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // --- Monitor pipeline stage transitions until result is ready ---
        begin : stage_monitor
            forever begin
                @(posedge clk);
                $write("[T=%0t ns]  Stage: ", $time);
                print_stage(stage_dbg);
                $write("  |  num_A=%-3d  num_B=%-3d  |  is_prime_A=%b  is_prime_B=%b  valid=%b\n",
                        num_A, num_B, is_prime_A, is_prime_B, valid_out);
                if (valid_out) disable stage_monitor;
            end
        end

        // --- Wait 1 delta for outputs to settle, then print final result ---
        #1;
        $display("------------------------------------------------------------");
        $display("  RESULT  ->  num_A = %-3d  |  is_prime_A = %b  (%s)",
                  a, is_prime_A, is_prime_A ? "PRIME" : "NOT PRIME");
        $display("  RESULT  ->  num_B = %-3d  |  is_prime_B = %b  (%s)",
                  b, is_prime_B, is_prime_B ? "PRIME" : "NOT PRIME");
        $display("------------------------------------------------------------\n");

        // --- Gap before next test ---
        repeat(3) @(posedge clk);
    end
endtask

// =============================================================================
// STIMULUS — EDIT ONLY THIS SECTION TO CHANGE YOUR INPUT NUMBERS
//
//   Syntax:  apply_test(8'd<number_A>, 8'd<number_B>);
//
//   - Numbers must be between 0 and 255 (8-bit)
//   - Hardware figures out prime or not — you don't provide the answer
//   - Add or remove apply_test lines freely
// =============================================================================
integer test_num;

initial begin
    // --- Reset ---
    rst    = 1'b1;
    start  = 1'b0;
    num_A  = 8'd0;
    num_B  = 8'd0;
    test_num = 1;

    repeat(3) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    $display("=============================================================");
    $display("  5-STAGE PIPELINED PRIME DETECTOR  |  NCLaunch + SimVision  ");
    $display("=============================================================");
    $display("  stage_dbg:  0=IDLE  1=IF  2=ID  3=EX  4=MEM  5=WB         ");
    $display("  is_prime = 1 (HIGH waveform) → PRIME                       ");
    $display("  is_prime = 0 (LOW  waveform) → NOT PRIME                   ");
    $display("=============================================================\n");

    // -----------------------------------------------------------------
    // >>>  CHANGE YOUR INPUT NUMBERS HERE  <<<
    //      Just edit the numbers inside apply_test(8'd?, 8'd?)
    //      You do NOT need to know or provide the expected answer.
    //      The hardware pipeline computes it and shows you the result.
    // -----------------------------------------------------------------

    $display(">>> TEST %0d", test_num); test_num = test_num + 1;
    apply_test(8'd7, 8'd11);       // Both prime

    $display(">>> TEST %0d", test_num); test_num = test_num + 1;
    apply_test(8'd9, 8'd15);       // Both not prime

    $display(">>> TEST %0d", test_num); test_num = test_num + 1;
    apply_test(8'd13, 8'd20);      // A prime, B not prime

    $display(">>> TEST %0d", test_num); test_num = test_num + 1;
    apply_test(8'd2, 8'd3);        // Edge: smallest primes

    $display(">>> TEST %0d", test_num); test_num = test_num + 1;
    apply_test(8'd1, 8'd0);        // Edge: 0 and 1 are NOT prime


    // -----------------------------------------------------------------
    // >>> ADD YOUR OWN TESTS BELOW — just copy and paste this line:
    //     apply_test(8'd<your_A>, 8'd<your_B>);
    // -----------------------------------------------------------------

    // apply_test(8'd53, 8'd60);   // Example: uncomment to test 53 and 60

    // -----------------------------------------------------------------

    $display("=============================================================");
    $display("  SIMULATION DONE — View waveforms in SimVision              ");
    $display("  Observe is_prime_A / is_prime_B toggling HIGH for primes   ");
    $display("  stage_dbg shows pipeline: IF->ID->EX->EX...->MEM->WB      ");
    $display("=============================================================");

    $finish;
end

// =============================================================================
// VCD DUMP — SimVision waveform file
// =============================================================================
initial begin
    $dumpfile("prime_pipeline.vcd");
    $dumpvars(0, tb_prime_pipeline);
end

// =============================================================================
// TIMEOUT WATCHDOG
// =============================================================================
initial begin
    #500000;
    $display("ERROR: Simulation TIMEOUT");
    $finish;
end

endmodule
// =============================================================================
// END OF FILE: tb_prime_pipeline.v
// =============================================================================
