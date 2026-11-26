`timescale 1ns/1ps
module async_fifo_tb #(
    parameter integer ADDR_BITS = 3
);
    localparam integer DEPTH = 1 << ADDR_BITS;
    localparam integer LIMIT = 300;
    reg w_clk=0, r_clk=0, w_reset_n=0, r_reset_n=0;
    reg w_valid=0, r_ready=0;
    reg [15:0] w_data=0;
    wire [15:0] r_data;
    wire w_ready, r_valid;

    // Odd timestamps for writer's rising edges; even for reader's.
    // This separates scoreboard writes and reads without changing clock ratio.
    always #3 w_clk = ~w_clk;
    initial begin
        #1;
        forever #5 r_clk = ~r_clk;
    end
    async_fifo #(.ADDR_BITS(ADDR_BITS)) dut (.*);

    integer pushed=0, popped=0, w_stall=0, r_stall=0, empty_requests=0;
    reg [15:0] ordered [0:LIMIT-1];
    reg [15:0] prev_data;
    reg read_stalled=0;
    reg [15:0] wx=16'h1234, rx=16'hBEEF;
    integer phase=0;

    function automatic [15:0] step(input [15:0] x);
        step = {x[14:0], x[15]^x[13]^x[12]^x[10]};
    endfunction

    always @(negedge w_clk) begin
        if (!w_reset_n) begin
            w_valid = 0;
        end else begin
            wx = step(wx);
            // Hold offered data until the preceding rising edge accepted it.
            if (!w_valid || pushed != w_data) begin
                w_valid = pushed < LIMIT && (phase == 0 || wx[1:0] != 0);
                w_data = pushed[15:0];
            end
        end
    end

    always @(negedge r_clk) begin
        rx = step(rx);
        r_ready = r_reset_n && phase > 0 && (phase == 2 || rx[2:0] > 2);
    end

    always @(posedge w_clk) if (w_reset_n) begin
        if (w_valid && w_ready) begin
            if (pushed-popped >= DEPTH) $fatal(1, "overflow at %0t", $time);
            if (pushed >= LIMIT) $fatal(1, "unexpected transfer");
            ordered[pushed] = w_data;
            pushed = pushed + 1;
        end
        if (w_valid && !w_ready) w_stall = w_stall + 1;
    end

    always @(posedge r_clk) if (r_reset_n) begin
        if (read_stalled && (!r_valid || r_data !== prev_data))
            $fatal(1, "read data not stable under backpressure");
        read_stalled = r_valid && !r_ready;
        prev_data = r_data;
        if (read_stalled) r_stall = r_stall + 1;
        if (!r_valid && r_ready) empty_requests = empty_requests + 1;
        if (r_valid && r_ready) begin
            if (popped >= pushed) $fatal(1, "underflow at %0t", $time);
            if (r_data !== ordered[popped])
                $fatal(1, "index %0d: got %0h, want %0h", popped, r_data, ordered[popped]);
            popped = popped + 1;
        end
    end

    initial begin
        // Changes just after each domain edge approximate a reset synchronizer output.
        repeat (3) @(posedge w_clk);
        #0.1 w_reset_n = 1;
        repeat (3) @(posedge r_clk);
        #0.1 r_reset_n = 1;
        repeat (3 * DEPTH) @(negedge w_clk);
        #0.1;
        if (pushed != DEPTH || w_ready !== 0 || w_stall == 0)
            $fatal(1, "did not reach full capacity and writer backpressure");
        phase = 1;
        wait (pushed == LIMIT);
        @(negedge r_clk);
        #0.1 phase = 2;
        wait (popped == LIMIT);
        repeat (5) @(negedge r_clk);
        if (r_valid !== 0 || empty_requests == 0 || r_stall == 0)
            $fatal(1, "empty/backpressure coverage not reached");
        $display("PASS depth=%0d pushed=%0d popped=%0d writer_stall=%0d reader_stall=%0d empty_requests=%0d",
            DEPTH,pushed,popped,w_stall,r_stall,empty_requests);
        $finish;
    end

    initial begin
        #40000;
        $fatal(1, "timeout pushed=%0d popped=%0d", pushed, popped);
    end
endmodule
