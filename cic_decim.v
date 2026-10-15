

module cic_decim #(
    parameter N         = 4,    
    parameter R         = 512,  
    parameter M         = 1,     
    parameter IN_W      = 2,     
    parameter OUT_W     = 20,   
    parameter GAIN_LOG2 = 0     
) (
    input  wire                     clk,
    input  wire                     rst,      
    input  wire                     en,       
    input  wire signed [IN_W-1:0]   din,
    output reg  signed [OUT_W-1:0]  dout,
    output reg                      dvalid    
);
    localparam LG   = $clog2(R*M);
    localparam BMAX = N*LG + IN_W;                         // register width
    localparam RS   = N*LG + IN_W - 2 - (OUT_W-1) - GAIN_LOG2;  // right shift
    localparam CW   = (R > 1) ? $clog2(R) : 1;

    
    
    // Integrators (input rate)
    reg signed [BMAX-1:0] integ [0:N-1];
    reg        [CW-1:0]   cnt;
    wire signed [BMAX-1:0] din_ext = {{(BMAX-IN_W){din[IN_W-1]}}, din};
    wire take = en && (cnt == R-1);                        // decimation instant

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            cnt <= 0;
            for (i = 0; i < N; i = i + 1) integ[i] <= 0;
        end else if (en) begin
            cnt      <= (cnt == R-1) ? {CW{1'b0}} : cnt + 1'b1;
            integ[0] <= integ[0] + din_ext;
            for (i = 1; i < N; i = i + 1) integ[i] <= integ[i] + integ[i-1];
        end
    end

    // Combs (decimated rate)
    wire signed [BMAX-1:0] cd [0:N];
    wire                   cv [0:N];
    assign cd[0] =integ[N-1];
    assign cv[0] =take;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : comb_stage
            cic_comb #(.W(BMAX), .M(M)) u_comb (
                .clk(clk), .rst(rst),
                .vin(cv[g]),   .din(cd[g]),
                .vout(cv[g+1]), .dout(cd[g+1])
            );
        end
    endgenerate

    
    localparam signed [OUT_W-1:0] MAXV = {1'b0, {(OUT_W-1){1'b1}}};
    localparam signed [OUT_W-1:0] MINV = {1'b1, {(OUT_W-1){1'b0}}};
    wire signed [BMAX:0] maxe = MAXV;
    wire signed [BMAX:0] mine = MINV;
    wire signed [BMAX:0] half = {{BMAX{1'b0}}, 1'b1} << (RS-1);
    wire signed [BMAX:0] rnd  = {cd[N][BMAX-1], cd[N]} + half;
    wire signed [BMAX:0] shr  = rnd >>> RS;

    always @(posedge clk) begin
        if (rst) begin
            dout   <= 0;
            dvalid <= 1'b0;
        end else begin
            dvalid <= cv[N];
            if (cv[N]) begin
                if      (shr > maxe) dout <= MAXV;
                else if (shr < mine) dout <= MINV;
                else                 dout <= shr[OUT_W-1:0];
            end
        end
    end
endmodule

