// Dual-clock FIFO. Assert resets together and release them synchronously per domain.
module async_fifo #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_BITS = 3 // Must be >= 2; depth = 2**ADDR_BITS.
) (
    input  wire                  w_clk,
    input  wire                  w_reset_n,
    input  wire                  w_valid,
    input  wire [DATA_WIDTH-1:0] w_data,
    output wire                  w_ready,
    input  wire                  r_clk,
    input  wire                  r_reset_n,
    output wire                  r_valid,
    input  wire                  r_ready,
    output wire [DATA_WIDTH-1:0] r_data
);
    localparam PTR_BITS = ADDR_BITS + 1;
    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_BITS)-1];
    reg [PTR_BITS-1:0] w_bin, w_gray, r_bin, r_gray;
    (* ASYNC_REG = "TRUE" *) reg [PTR_BITS-1:0] r_gray_w1, r_gray_w2;
    (* ASYNC_REG = "TRUE" *) reg [PTR_BITS-1:0] w_gray_r1, w_gray_r2;
    reg w_full, r_empty;

    wire w_fire = w_valid && w_ready;
    wire r_fire = r_valid && r_ready;
    wire [PTR_BITS-1:0] w_next = w_bin + {{ADDR_BITS{1'b0}}, w_fire};
    wire [PTR_BITS-1:0] r_next = r_bin + {{ADDR_BITS{1'b0}}, r_fire};
    wire [PTR_BITS-1:0] w_gray_next = w_next ^ (w_next >> 1);
    wire [PTR_BITS-1:0] r_gray_next = r_next ^ (r_next >> 1);
    wire [PTR_BITS-1:0] full_target =
        {~r_gray_w2[PTR_BITS-1:PTR_BITS-2], r_gray_w2[PTR_BITS-3:0]};

    assign w_ready = w_reset_n && !w_full;
    assign r_valid = r_reset_n && !r_empty;
    // First word is visible before its accepting read edge. Ignore data when invalid.
    assign r_data = mem[r_bin[ADDR_BITS-1:0]];

    always @(posedge w_clk) begin
        if (w_fire)
            mem[w_bin[ADDR_BITS-1:0]] <= w_data;
    end

    always @(posedge w_clk or negedge w_reset_n) begin
        if (!w_reset_n) begin
            w_bin <= 0;
            w_gray <= 0;
            w_full <= 1'b0;
            r_gray_w1 <= 0;
            r_gray_w2 <= 0;
        end else begin
            r_gray_w1 <= r_gray;
            r_gray_w2 <= r_gray_w1;
            w_bin <= w_next;
            w_gray <= w_gray_next;
            w_full <= (w_gray_next == full_target);
        end
    end

    always @(posedge r_clk or negedge r_reset_n) begin
        if (!r_reset_n) begin
            r_bin <= 0;
            r_gray <= 0;
            r_empty <= 1'b1;
            w_gray_r1 <= 0;
            w_gray_r2 <= 0;
        end else begin
            w_gray_r1 <= w_gray;
            w_gray_r2 <= w_gray_r1;
            r_bin <= r_next;
            r_gray <= r_gray_next;
            r_empty <= (r_gray_next == w_gray_r2);
        end
    end
endmodule
