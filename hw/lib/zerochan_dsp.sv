module zerochan_mixer #
( parameter int DW = 12
, parameter int AW = 16
, parameter int ID = 10

, parameter int LUT_WIDTH = 16
, parameter int LUT_DEPTH = 10
)
( input  logic                 clk
, input  logic                 rst
, input  logic                 ce

, input  logic        [AW-1:0] i_vel

, input  logic        [ID-1:0] i_id
, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic        [ID-1:0] o_id
, output logic signed [  DW:0] o_re
, output logic signed [  DW:0] o_im
);

    localparam logic [LUT_DEPTH-1:0] MAX_ADDR = (2 ** LUT_DEPTH) - 1;
    localparam int FW = LUT_WIDTH + 1;

    logic [LUT_WIDTH-1:0] lut [2**LUT_DEPTH];

    logic [AW-1:0] acc;

    logic signed [DW-1:0] re_1, im_1;
    logic [ID-1:0] id_1;

    logic [1:0] quadrant;
    logic [LUT_DEPTH-1:0] sin_addr;
    logic [LUT_DEPTH-1:0] cos_addr;

    logic signed [DW-1:0] re_2, im_2;
    logic [ID-1:0] id_2;

    logic signed [FW-1:0] sin, cos;

    logic signed [DW-1:0] re_3, im_3;
    logic [ID-1:0] id_3;

    logic [ID-1:0] id_4, id_5, id_6;

    always_ff @(posedge clk) begin
        if (rst) begin
            acc <= 0;
        end else if (ce) begin
            acc <= acc + i_vel;

            {re_1, im_1} <= {i_re, i_im};
            id_1 <= i_id;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            quadrant <= acc[AW-1-:2];
            sin_addr <= acc[AW-3-:LUT_DEPTH];
            cos_addr <= MAX_ADDR - acc[AW-3-:LUT_DEPTH];

            {re_2, im_2} <= {re_1, im_1};
            id_2 <= id_1;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            unique case (quadrant)
                2'b00: begin
                    cos <= $signed({1'b0, lut[cos_addr]});
                    sin <= $signed({1'b0, lut[sin_addr]});
                end
                2'b01: begin
                    cos <= -$signed({1'b0, lut[sin_addr]});
                    sin <=  $signed({1'b0, lut[cos_addr]});
                end
                2'b10: begin
                    cos <= -$signed({1'b0, lut[cos_addr]});
                    sin <= -$signed({1'b0, lut[sin_addr]});
                end
                2'b11: begin
                    cos <=  $signed({1'b0, lut[sin_addr]});
                    sin <= -$signed({1'b0, lut[cos_addr]});
                end
            endcase

            {re_3, im_3} <= {re_2, im_2};
            id_3 <= id_2;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            id_4 <= id_3;
            id_5 <= id_4;
            id_6 <= id_5;
            o_id <= id_6;
        end
    end

    zerochan_cmult #
    ( .A(DW)
	, .B(FW)
	, .R(FW-1)
    ) u_mult
    ( .clk(clk)
    , .ce(ce)

    , .a_re(re_3)
    , .a_im(im_3)

    , .b_re(cos)
    , .b_im(sin)

    , .o_re(o_re)
	, .o_im(o_im)
    );

    initial begin
        int i;

        for (i = 0; i < 2**LUT_DEPTH; i++) begin : gen_lut
           var automatic real theta;

           theta = ($atan(1.0) * 2) / (2**LUT_DEPTH) * real'(i);
           lut[i] = lut_scale($sin(theta) * $cos($atan(1.0)));
        end
    end

    function automatic [LUT_WIDTH-1:0] lut_scale(real x);
        localparam int MAX = ((1 << LUT_WIDTH) - 1);

        var automatic real scaled = x * (1 << LUT_WIDTH);
        var automatic int v = $rtoi(scaled + 0.5);

        if (v > MAX) v = MAX;

        return v;
    endfunction

endmodule : zerochan_mixer
