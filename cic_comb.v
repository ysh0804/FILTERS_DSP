module cic_comb #(
    parameter W = 38,
    parameter M = 1
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 vin,
    input  wire signed [W-1:0]  din,
    output reg                  vout,
    output reg  signed [W-1:0]  dout
);
    reg signed [W-1:0] d [0:M-1];
    integer k;
    always @(posedge clk) begin
        if (rst) begin
            vout <= 1'b0;
            dout <= 0;
            for (k = 0; k < M; k = k + 1) d[k] <= 0;
        end else begin
            vout <= vin;
            if (vin) begin
                dout <= din - d[M-1];          // wraps modulo 2^W (intended)
                d[0] <= din;
                for (k = 1; k < M; k = k + 1) d[k] <= d[k-1];
            end
        end
    end
endmodule
