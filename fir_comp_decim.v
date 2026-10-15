

module fir_comp_decim #(
    parameter L         = 23,
    parameter DEC       = 4,
    parameter IN_W      = 24,
    parameter OUT_W     = 20,
    parameter COEF_W    = 18,
    parameter COEF_FRAC = 16,

    parameter [((L+1)/2)*COEF_W-1:0] COEFS = {
        18'h12508,
        18'h0E4B2,  
        18'h05757,  
        18'h3E47E,  
        18'h3C766,  
        18'h3E8B8,  
        18'h00CB0,  
        18'h01327,  
        18'h0062C,  
        18'h3FBBB,  
        18'h3FB1D,  
        18'h3FE5F   
    }
) (
    input wire clk,
    input wire rst,
    input wire vin,
    input wire signed [IN_W-1:0] din,

    output reg vout,
    output reg signed [OUT_W-1:0] dout
);

    localparam HALF  =(L+1)/2;
    localparam NM    =HALF-1;
    localparam SUM_W =IN_W+1;
    localparam PRD_W =SUM_W+COEF_W;
    localparam ACC_W =PRD_W+$clog2(HALF)+1;
    localparam SH    =COEF_FRAC+IN_W-OUT_W;
    localparam KW    =$clog2(HALF)+1;
    localparam PW    =(DEC > 1) ? $clog2(DEC) : 1;

    // Input 
    reg signed [IN_W-1:0] dl [0:L-1];
    reg [PW-1:0] pc;
    reg go;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            pc <=0;
            go <=0;

            for (i = 0; i < L; i = i+1)
                dl[i] <=0;
        end
        else begin
            go <=0;

            if (vin) begin
                dl[0] <=din;

                for (i = 1; i < L; i = i+1)
                    dl[i] <=dl[i-1];

                if (pc ==DEC-1)
                    pc <=0;
                else
                    pc <=pc+1'b1;

                go <=(pc == DEC-1);
            end
        end
    end

    // control
    reg run;
    reg [KW-1:0] k;

    wire issue = go | run;
    wire [KW-1:0] kk = go ? 0 : k;

    always @(posedge clk) begin
        if (rst) begin
            run <=0;
            k <=0;
        end
        else if (go) begin
            run <=(NM > 0);
            k <=1;
        end
        else if (run) begin
            k <= k+1'b1;

            if (k == NM)
                run <= 0;
        end
    end

    
    reg signed [SUM_W-1:0] s0;
    reg signed [COEF_W-1:0] c0;
    reg v0, f0, l0;

    // Multiply samples by coefficients
    reg signed [PRD_W-1:0] p1;
    reg v1, f1, l1;

    // Accumulate 
    reg signed [ACC_W-1:0] acc;
    reg vacc;

    wire signed [IN_W-1:0] xa = dl[kk];
    wire signed [IN_W-1:0] xb = dl[L-1-kk];

    wire signed [SUM_W-1:0] pair =(kk == NM) ? {xa[IN_W-1], xa} :({xa[IN_W-1], xa} + {xb[IN_W-1], xb});

    wire signed [COEF_W-1:0] cf =COEFS[kk*COEF_W +: COEF_W];

    wire signed [ACC_W-1:0] p1_ext =p1;

    always @(posedge clk) begin
        if (rst) begin
            v0 <=0;
            v1 <=0;
            vacc <=0;
            f0 <=0;
            l0 <=0;
            f1 <=0;
            l1 <=0;
            s0 <=0;
            c0 <=0;
            p1 <=0;
            acc <=0;
        end
        else begin
            v0 <=issue;
            f0 <=(kk == 0);
            l0 <=(kk == NM);
            s0 <= pair;
            c0 <= cf;
            v1 <= v0;
            f1 <= f0;
            l1 <= l0;
            p1 <= s0*c0;
            vacc <= v1 & l1;

            if (v1) begin
                if (f1)
                    acc<=p1_ext;
                else
                    acc<=acc+p1_ext;
            end
        end
    end

    localparam signed [OUT_W-1:0] MAXV =
        {1'b0, {(OUT_W-1){1'b1}}};

    localparam signed [OUT_W-1:0] MINV =
        {1'b1, {(OUT_W-1){1'b0}}};

    wire signed [ACC_W-1:0] maxe = MAXV;
    wire signed [ACC_W-1:0] mine = MINV;

    wire signed [ACC_W-1:0] half =
        {{(ACC_W-1){1'b0}}, 1'b1} << (SH-1);

    wire signed [ACC_W-1:0] rnd = acc+half;
    wire signed [ACC_W-1:0] shr = rnd >>> SH;

    always @(posedge clk) begin
        if (rst) begin
            vout <= 0;
            dout <= 0;
        end
        else begin
            vout <= vacc;

            if (vacc) begin
                if (shr > maxe)
                    dout <= MAXV;
                else if (shr < mine)
                    dout <= MINV;
                else
                    dout <= shr[OUT_W-1:0];
            end
        end
    end

endmodule
