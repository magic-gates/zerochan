module zerochan_rx_eq #
( parameter int FFT_N = 10
, parameter int INPUT_WIDTH = 18
, parameter int OUTPUT_WIDTH = 16

, parameter int PILOT_SPACING = 16
, parameter int PILOT_OFFSET = 8

, parameter int GUARD_FROM = 488
, parameter int GUARD_UNTIL = 536

, parameter int INDEX_WIDTH = $clog2(FFT_N)
, parameter int PILOTS = FFT_N / PILOT_SPACING
, parameter int PILOTS_WIDTH = $clog2(PILOTS)
, parameter int OFFSET_WIDTH = $clog2(PILOT_SPACING)
)
( input  logic                     clk
, input  logic                     i_ce

, input  logic [  INDEX_WIDTH-1:0] i_idx
, input  logic [INPUT_WIDTH*2-1:0] i_est [4]

, input  logic [  INPUT_WIDTH-1:0] i_re
, input  logic [  INPUT_WIDTH-1:0] i_im

, output logic [  INDEX_WIDTH-1:0] o_idx
, output logic                     o_valid

, output logic [ OUTPUT_WIDTH-1:0] o_re
, output logic [ OUTPUT_WIDTH-1:0] o_im
);

    // assign o_idx = i_idx;
    // assign o_valid = 1'b1;
    // assign o_re = 0;
    // assign o_im = 0;

    localparam logic [PILOTS_WIDTH-1:0] NO_P3_PILOT = ((GUARD_FROM - PILOT_OFFSET) / PILOT_SPACING) - 1;
    localparam logic [PILOTS_WIDTH-1:0] NO_P0_PILOT = ((GUARD_UNTIL - PILOT_OFFSET) / PILOT_SPACING);

    wire is_pilot_0 = i_idx[OFFSET_WIDTH-1:0] == OFFSET_WIDTH'(PILOT_OFFSET);
    wire [PILOTS_WIDTH-1:0] pilot_idx_0 = i_idx[INDEX_WIDTH-1-:PILOTS_WIDTH];
    wire [INDEX_WIDTH-1:0] pilot_rel_idx = i_idx - INDEX_WIDTH'(PILOT_OFFSET);

    logic is_pilot, no_p0, no_p3;
    logic [PILOTS_WIDTH-1:0] pilot_idx;
    logic [OFFSET_WIDTH-1:0] pilot_rel;
    logic [INDEX_WIDTH-1:0] idx_1;

    logic [INPUT_WIDTH*2-1:0] est_1 [4];
    logic [INPUT_WIDTH-1:0] re_1, im_1;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            is_pilot <= is_pilot_0;
            pilot_idx <= pilot_idx_0;
            pilot_rel <= pilot_rel_idx[OFFSET_WIDTH-1:0];

            if (is_pilot_0) begin
                if (pilot_idx == NO_P3_PILOT) begin
                    no_p0 <= 1'b0;
                    no_p3 <= 1'b1;
                end else if (pilot_idx == NO_P0_PILOT) begin
                    no_p0 <= 1'b1;
                    no_p3 <= 1'b0;
                end else begin
                    no_p0 <= 1'b0;
                    no_p3 <= 1'b0;
                end
            end

            idx_1 <= i_idx;
            est_1 <= i_est;
            {re_1, im_1} <= {i_re, i_im};
        end
    end

    logic signed [INPUT_WIDTH-1:0] h_re, h_im;
    wire [INPUT_WIDTH*2:0] h_dbg = (h_re * h_re) + (h_im * h_im);

    zerochan_rx_eq_spline_5 #
    ( .DATA_WIDTH(INPUT_WIDTH)
    , .FRAC_WIDTH(OFFSET_WIDTH)
    ) u_spline_re
    ( .clk(clk)
    , .i_ce(i_ce)

    , .i_frac(pilot_rel)

    , .i_no_p0(no_p0)
    , .i_no_p3(no_p3)

    , .i_p0(est_1[0][INPUT_WIDTH*2-1-:INPUT_WIDTH])
    , .i_p1(est_1[1][INPUT_WIDTH*2-1-:INPUT_WIDTH])
    , .i_p2(est_1[2][INPUT_WIDTH*2-1-:INPUT_WIDTH])
    , .i_p3(est_1[3][INPUT_WIDTH*2-1-:INPUT_WIDTH])

    , .o_val(h_re)
    );

    zerochan_rx_eq_spline_5 #
    ( .DATA_WIDTH(INPUT_WIDTH)
    , .FRAC_WIDTH(OFFSET_WIDTH)
    ) u_spline_im
    ( .clk(clk)
    , .i_ce(i_ce)

    , .i_frac(pilot_rel)

    , .i_no_p0(no_p0)
    , .i_no_p3(no_p3)

    , .i_p0(est_1[0][INPUT_WIDTH-1:0])
    , .i_p1(est_1[1][INPUT_WIDTH-1:0])
    , .i_p2(est_1[2][INPUT_WIDTH-1:0])
    , .i_p3(est_1[3][INPUT_WIDTH-1:0])

    , .o_val(h_im)
    );

    logic [INPUT_WIDTH-1:0] re_2, im_2;
    logic [INPUT_WIDTH-1:0] re_3, im_3;
    logic [INPUT_WIDTH-1:0] re_4, im_4;
    logic [INPUT_WIDTH-1:0] re_5, im_5;
    logic [INPUT_WIDTH-1:0] re_6, im_6;

    logic [INDEX_WIDTH-1:0] idx_2, idx_3, idx_4, idx_5, idx_6;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            {re_2, im_2} <= {re_1, im_1};
            {re_3, im_3} <= {re_2, im_2};
            {re_4, im_4} <= {re_3, im_3};
            {re_5, im_5} <= {re_4, im_4};
            {re_6, im_6} <= {re_5, im_5};

            idx_2 <= idx_1;
            idx_3 <= idx_2;
            idx_4 <= idx_3;
            idx_5 <= idx_4;
            idx_6 <= idx_5;
        end
    end

    logic signed [24:0] m_re, m_im; // Q1.17 * Q1.17 = Q2.34 => Q2.23

    zerochan_lib_mult_4
        #(INPUT_WIDTH, INPUT_WIDTH, INPUT_WIDTH*2-25, 1'b1)
    u_mult
        (clk, i_ce, re_6, im_6, h_re, h_im, m_re, m_im);

    logic signed [24:0] m_re_1, m_im_1;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            {m_re_1, m_im_1} <= {m_re, m_im};
        end
    end

    localparam int K = $clog2(INPUT_WIDTH*2) + 1;

    logic signed [K-1:0] k;
    logic [17:0] rec;

    zerochan_rx_eq_scale_5 #(INPUT_WIDTH) u_scale
    ( .clk(clk)
    , .i_ce(i_ce)

    , .i_re(h_re)
    , .i_im(h_im)

    , .o_k(k)
    , .o_rec(rec)
    );

    logic [INDEX_WIDTH-1:0] idx_7, idx_8, idx_9, idx_10, idx_11;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            idx_7 <= idx_6;
            idx_8 <= idx_7;
            idx_9 <= idx_8;
            idx_10 <= idx_9;
            idx_11 <= idx_10;
        end
    end

    logic signed [25+18-1:0] s_re, s_im; // Q2.23 * Q2.16 = Q4.39

    logic [INDEX_WIDTH-1:0] idx_12;
    logic [K-1:0] shift;
    logic dir;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            s_re <= m_re_1 * $signed({1'b0, rec});
            s_im <= m_im_1 * $signed({1'b0, rec});

            shift <= k[K-1] ? -k : k;
            dir <= k[K-1];

            idx_12 <= idx_11;
        end
    end

    logic signed [25+18-1:0] u_re, u_im;
    logic [INDEX_WIDTH-1:0] idx_13;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (dir) begin
                u_re <= s_re >>> shift;
                u_im <= s_im >>> shift;
            end else begin
                u_re <= s_re << shift;
                u_im <= s_im << shift;
            end

            idx_13 <= idx_12;
        end
    end

    logic [25+18-2-1:0] sat_re, sat_im;

    zerochan_lib_sat_1
        #(25+18, 25+18-3)
    u_sat_re
        (clk, i_ce, u_re, sat_re);

    zerochan_lib_sat_1
        #(25+18, 25+18-3)
    u_sat_im
        (clk, i_ce, u_im, sat_im);

    logic [INDEX_WIDTH-1:0] idx_14;

    logic is_pilot_1;
    logic is_active_1;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            is_pilot_1 <= idx_13[OFFSET_WIDTH-1:0] == OFFSET_WIDTH'(PILOT_OFFSET);
            is_active_1 <= idx_13 != 0 && (idx_13 <= INDEX_WIDTH'(GUARD_FROM) || idx_13 >= INDEX_WIDTH'(GUARD_UNTIL));

            idx_14 <= idx_13;
        end
    end

    zerochan_lib_round_1 #(25+18-3, 25+18-3-OUTPUT_WIDTH) u_round_re
        (clk, i_ce, sat_re, o_re);

    zerochan_lib_round_1 #(25+18-3, 25+18-3-OUTPUT_WIDTH) u_round_im
        (clk, i_ce, sat_im, o_im);

    always_ff @(posedge clk) begin
        if (i_ce) begin
            o_idx <= idx_14;
            o_valid <= is_active_1 & ~is_pilot_1;
        end
    end

endmodule : zerochan_rx_eq

module zerochan_rx_eq_spline_5 #
( parameter int DATA_WIDTH = 16
, parameter int FRAC_WIDTH = 4
)
( input  logic                         clk

, input  logic                         i_ce

, input  logic        [FRAC_WIDTH-1:0] i_frac
, input  logic                         i_no_p0
, input  logic                         i_no_p3

, input  logic signed [DATA_WIDTH-1:0] i_p0
, input  logic signed [DATA_WIDTH-1:0] i_p1
, input  logic signed [DATA_WIDTH-1:0] i_p2
, input  logic signed [DATA_WIDTH-1:0] i_p3

, output logic signed [DATA_WIDTH-1:0] o_val
);

    logic signed [DATA_WIDTH+2:0] c0, c1, c2, c3;
    logic signed [DATA_WIDTH+1:0] m0, m1;
    logic [FRAC_WIDTH-1:0] frac_1;

    always_comb begin
        if (i_no_p0) begin
            m0 = i_p2 - i_p1;
        end else begin
            m0 = (i_p2 >>> 1) - (i_p0 >>> 1);
        end

        if (i_no_p3) begin
            m1 = i_p2 - i_p1;
        end else begin
            m1 = (i_p3 >>> 1) - (i_p1 >>> 1);
        end
    end

    always_ff @(posedge clk) begin
        if (i_ce) begin
            c0 <= i_p1;
            c1 <= m0;
            c2 <= (i_p2 + (i_p2 << 1)) - (i_p1 + (i_p1 << 1)) - (m0 << 1) - m1;
            c3 <= (i_p1 << 1) - (i_p2 << 1) + m0 + m1;

            frac_1 <= i_frac;
        end
    end

    logic signed [DATA_WIDTH+4:0] s1;
    logic signed [DATA_WIDTH+2:0] c0_1, c1_1;
    logic [FRAC_WIDTH-1:0] frac_2;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            s1 <= ((c3 * $signed({1'b0, frac_1})) >>> FRAC_WIDTH) + c2;
            c0_1 <= c0;
            c1_1 <= c1;
            frac_2 <= frac_1;
        end
    end

    logic signed [DATA_WIDTH+4:0] s2;
    logic signed [DATA_WIDTH+2:0] c0_2;
    logic [FRAC_WIDTH-1:0] frac_3;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            s2  <= ((s1 * $signed({1'b0, frac_2})) >>> FRAC_WIDTH) + c1_1;
            c0_2 <= c0_1;
            frac_3 <= frac_2;
        end
    end

    logic signed [DATA_WIDTH+4:0] s3;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            s3 <= ((s2 * $signed({1'b0, frac_3})) >>> FRAC_WIDTH) + c0_2;
        end
    end

    zerochan_lib_sat_1 #(DATA_WIDTH+5, DATA_WIDTH)
        u_clamp (clk, i_ce, s3, o_val);

endmodule : zerochan_rx_eq_spline_5

module zerochan_rx_eq_scale_5 #
( parameter int W = 16
, parameter int LZC = $clog2(W*2+1)
, parameter int K = LZC + 1
)
( input  logic                clk
, input  logic                i_ce

, input  logic signed [W-1:0] i_re
, input  logic signed [W-1:0] i_im

, output logic signed [K-1:0] o_k
, output logic        [ 17:0] o_rec
);

    logic signed [W*2:0] den; // Q3.34

    always_ff @(posedge clk) begin
        if (i_ce) begin
            den <= (i_re * i_re) + (i_im * i_im);
        end
    end

    logic [LZC-1:0] lzc;
    logic [W*2:0] den_norm;
    logic signed [K-1:0] k;

    zerochan_lib_lsc_0 #(W*2+1) u_lzc (den, lzc);

    always_ff @(posedge clk) begin
        if (i_ce) begin
            den_norm <= den <<< lzc;
            k <= K'(lzc) - K'(2);
        end
    end

    logic [K-1:0] k_1, k_2;

    zerochan_rx_eq_reciprocal_3 #(W*2, 16) u_rec
        (clk, i_ce, den_norm[W*2-1:0], o_rec);

    always_ff @(posedge clk) begin
        if (i_ce) begin
            k_1 <= k;
            k_2 <= k_1;
            o_k <= k_2;
        end
    end

endmodule : zerochan_rx_eq_scale_5

module zerochan_rx_eq_reciprocal_3 #
( parameter int DEN = 16
, parameter int WID = DEN
, parameter int REC = WID + 2

, parameter int DEPTH = 8
)
( input  logic           clk

, input  logic           i_ce

, input  logic [DEN-1:0] i_den
, output logic [REC-1:0] o_rec
);

    localparam int DX_W = DEN-DEPTH-1;

    wire [DEPTH-1:0] addr_0 = i_den[DEN-2-:DEPTH];
    wire [DX_W-1:0] dx_0 = i_den[DX_W-1:0];

    logic [REC*2-1:0] rom_1 [2 ** DEPTH];
    logic [REC-1:0] slope_1, rec_1;
    logic [DX_W-1:0] dx_1;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            {rec_1, slope_1} <= rom_1[addr_0];
            dx_1 <= dx_0;
        end
    end

    initial begin
        localparam int SEG = 2 ** DEPTH;
        localparam real DX = 0.5 / real'(SEG);

        var automatic int i;

        for (i = 0; i < SEG; i++) begin
            var automatic real x0, x1, y0, y1, slope;
            var automatic int slope_fixed, rec_fixed;

            x0 = 0.5 + real'(i) * DX;
            x1 = x0 + DX;

            y0 = 1.0 / x0;
            y1 = 1.0 / x1;

            slope = (y1 - y0) / DX;

            slope_fixed = $rtoi($floor(-slope * (2.0 ** WID) + 0.5));
            rec_fixed = $rtoi($floor(y0 * (2.0 ** WID) + 0.5));

            rom_1[i] = {rec_fixed[REC-1:0], slope_fixed[REC-1:0]};
        end
    end

    localparam logic [DEN-1:0] ROUND = 1 << (DEN - 1);

    logic [REC+DX_W-1:0] fine_2;
    logic [REC-1:0] rec_2;

    always_ff @(posedge clk) begin
       if (i_ce) begin
           fine_2 <= slope_1 * dx_1 + ROUND;
           rec_2 <= rec_1;
       end
    end

    always_ff @(posedge clk) begin
        if (i_ce) begin
            o_rec <= REC'(rec_2 - (fine_2 >> DEN));
        end
    end

endmodule : zerochan_rx_eq_reciprocal_3
