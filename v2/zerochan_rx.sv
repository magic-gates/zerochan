module zerochan_rx #
( parameter int DW = 12
)
( input  logic            clk
, input  logic            rst

, input  logic            s_axis_tvalid
, output logic            s_axis_tready
, input  logic [DW*2-1:0] s_axis_tdata

, output logic            m_axis_tvalid
, input  logic            m_axis_tready
, output logic [    31:0] m_axis_tdata
, output logic [     0:0] m_axis_tuser
);

    localparam int DW1 = DW + 1;
    localparam int TM = $clog2(32) + 2;

    logic in_ready, in_valid;
    logic signed [DW-1:0] in_re, in_im;

    logic mx_ready, mx_valid;
    logic signed [DW1-1:0] mx_re, mx_im;

    logic ps_ready, ps_valid;
    logic signed [DW1-1:0] ps_re, ps_im;

    logic tde_ready, tde_valid;
    logic signed [DW1-1:0] tde_re, tde_im;

    logic tm_ready, tm_valid;
    logic signed [DW1-1:0] tm_re, tm_im;
    logic sync;

    logic sm_ready, sm_valid;
    logic signed [DW1-1:0] sm_re, sm_im;

    assign m_axis_tvalid = sm_valid;
    assign m_axis_tdata = {{{3{sm_re[DW1-1]}}, sm_re}, {{3{sm_im[DW1-1]}}, sm_im}};
    assign sm_ready = m_axis_tready;

    zerochan_skid #(DW*2) u_skid
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(s_axis_tvalid)
    , .s_ready(s_axis_tready)
    , .s_data(s_axis_tdata)

    , .m_valid(in_valid)
    , .m_ready(in_ready)
    , .m_data({in_re, in_im})
    );

    zerochan_rx_mixer #
    ( .DW(DW)
	, .AW(16)

	, .LUT_WIDTH(14)
	, .LUT_DEPTH(11)
     ) u_mixer
    ( .clk(clk)
    , .rst(rst)

	, .i_vel(0)

	, .s_valid(in_valid)
	, .s_ready(in_ready)
	, .s_re(in_re)
	, .s_im(in_im)

	, .m_valid(mx_valid)
	, .m_ready(mx_ready)
	, .m_re(mx_re)
	, .m_im(mx_im)
    );

    zerochan_rx_ps #(DW1) u_ps
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(mx_valid)
    , .s_ready(mx_ready)
    , .s_re(mx_re)
    , .s_im(mx_im)

    , .m_valid(ps_valid)
    , .m_ready(ps_ready)
    , .m_re(ps_re)
    , .m_im(ps_im)
    );

    zerochan_rx_tde #(DW1) u_tde
    ( .clk(clk)
    , .rst(rst)

    , .i_sync(sync)

    , .s_valid(ps_valid)
    , .s_ready(ps_ready)
    , .s_re(ps_re)
    , .s_im(ps_im)

    , .m_valid(tde_valid)
    , .m_ready(tde_ready)
    , .m_re(tde_re)
    , .m_im(tde_im)
    );

    zerochan_rx_timing #
    ( .DW(DW1)
    , .BL(528)
    , .TF(48)
    , .SF(16)
    ) u_timing
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(tde_valid)
    , .s_ready(tde_ready)
    , .s_re(tde_re)
    , .s_im(tde_im)

    , .m_valid(tm_valid)
    , .m_ready(tm_ready)
    , .m_re(tm_re)
    , .m_im(tm_im)

    , .o_sync(sync)
    );

    zerochan_rx_sampler #
    ( .DW(DW1)
    , .BL(528)
    , .TF(48)
    ) u_sampler
    ( .clk(clk)
    , .rst(rst)

    , .i_sync(sync)

    , .s_valid(tm_valid)
    , .s_ready(tm_ready)
    , .s_re(tm_re)
    , .s_im(tm_im)

    , .m_valid(sm_valid)
    , .m_ready(sm_ready)
    , .m_re(sm_re)
    , .m_im(sm_im)
    );

endmodule : zerochan_rx

module zerochan_rx_tde #
( parameter int DW = 12
, parameter int LEN = 21
)
( input  logic                 clk
, input  logic                 rst

, input  logic                 i_sync

, input  logic                 s_valid
, output logic                 s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im
);

    localparam int unsigned W = 20;

    localparam int unsigned D = 7;
    localparam int unsigned IDX = $clog2(LEN);

    logic [1:0][DW-1:0] taps [LEN + D];
    logic [1:0][W-1:0] weights [LEN];

    logic [4:0] cnt;
    logic train;

    logic [1:0][15:0] ref_signal [32];
    logic [4:0] ref_addr;
    logic signed [DW-1:0] ref_re, ref_im;
    logic signed [DW:0] err_re, err_im;

    logic err_valid;

    logic [1:0][DW+W-1:0] product [LEN];
    logic [2:0] product_valid;
    logic [1:0][DW+W+$clog2(LEN)-1:0] sum_0, sum;
    logic [1:0][DW*2-1:0] sat;
    logic [1:0][DW-1:0] round;

    logic taps_ready, taps_valid;
    logic product_ready;
    logic sum_ready, sum_valid;
    logic sat_ready, sat_valid;
    logic round_ready, round_valid;

    assign train = i_sync || cnt < 31;

    assign ref_re = ref_signal[ref_addr][1][DW-1:0];
    assign ref_im = ref_signal[ref_addr][0][DW-1:0];

    assign taps_ready = !taps_valid || product_ready;
    assign product_ready = !product_valid[2] || sum_ready;
    assign sum_ready = !sum_valid || sat_ready;
    assign sat_ready = !sat_valid || round_ready;
    assign round_ready = !round_valid || m_ready;

    assign s_ready = taps_ready;
    assign m_valid = round_valid;
    assign m_re = round[1];
    assign m_im = round[0];

    initial $readmemh("ref.mem", ref_signal);

    always_ff @(posedge clk) begin
        if (rst) begin
            ref_addr <= 0;
            cnt <= 31;
            err_valid <= 0;
        end else if (train) begin
            if (m_valid && m_ready) begin
                err_re <= ref_re - m_re;
                err_im <= ref_im - m_im;

                ref_addr <= ref_addr + 'd1;
                cnt <= cnt + 'd1;

                err_valid <= 1'b1;
            end else begin
                err_valid <= 1'b0;
            end
        end else begin
            ref_addr <= 0;
            err_valid <= 0;

            if (i_sync) begin
                cnt <= 1;
            end
        end
    end

    logic signed [W+4:0] upd_re [LEN];
    logic signed [W+4:0] upd_im [LEN];
    logic upd_valid;

    always_ff @(posedge clk) begin
        for (int i = 0; i < LEN; i++) begin
            var automatic logic signed [DW-1:0] t_re, t_im;
            var automatic logic signed [DW-1:0] a, b, c, d;

            t_re = taps[i+D][1];
            t_im = taps[i+D][0];

            a = err_re[DW] ? -t_re : t_re;
            b = err_re[DW] ? -t_im : t_im;
            c = err_im[DW] ? -t_re : t_re;
            d = err_im[DW] ? -t_im : t_im;

            upd_re[i] <= ($signed(weights[i][1]) <<< 4) + (a + d);
            upd_im[i] <= ($signed(weights[i][0]) <<< 4) + (c - b);
        end

        upd_valid <= err_valid;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < LEN; i++) begin
                weights[i][1] <= 0;
                weights[i][0] <= 0;
            end

            weights[10][1] <= W'({(DW-1){1'b1}});
        end else if (upd_valid) begin
            // for (int i = 0; i < LEN; i++) begin
                // weights[i][1] <= upd_re[i] >>> 4;
                // weights[i][0] <= upd_im[i] >>> 4;
            // end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            taps <= '{default:'0};
        end else if (taps_ready) begin
            taps_valid <= 0;

            if (s_valid) begin
                taps_valid <= 1'b1;
                taps <= {{s_re, s_im}, taps[0:LEN+D-2]};
            end
        end
    end

    generate
        for (genvar i = 0; i < LEN; i++) begin : gen_dsp
            logic [IDX-1:0] idx;

            logic [1:0][DW-1:0] tap;
            logic [1:0][W-1:0] weight;

            assign tap = taps[i];
            assign weight = weights[i];

            zerochan_mult #
            ( .A(DW)
            , .B(W)
            , .R(0)
            ) u_mult
            ( .clk(clk)
            , .ce(sum_ready)

            , .a_re(tap[1])
            , .a_im(tap[0])

            , .b_re(weight[1])
            , .b_im(weight[0])

            , .o_re(product[i][1])
            , .o_im(product[i][0])
            );
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            product_valid <= 0;
        end else if (sum_ready) begin
            product_valid[0] <= taps_valid;
            product_valid[1] <= product_valid[0];
            product_valid[2] <= product_valid[1];
        end
    end

    always_comb begin
        sum_0 = 0;

        for (int i = 0; i < LEN; i++) begin
            sum_0[1] = $signed(sum_0[1]) + $signed(product[i][1]);
            sum_0[0] = $signed(sum_0[0]) + $signed(product[i][0]);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sum_valid <= 0;
        end else if (sum_ready) begin
            sum_valid <= product_valid[2];
            sum <= sum_0;
        end
    end

    zerochan_sat
        #(DW+W+$clog2(LEN), DW*2-1)
    u_sat_re
        (clk, sat_ready, sum[1], sat[1]);

    zerochan_sat
        #(DW+W+$clog2(LEN), DW*2-1)
    u_sat_im
        (clk, sat_ready, sum[0], sat[0]);

    always_ff @(posedge clk) begin
        if (rst) begin
            sat_valid <= 0;
        end else if (sat_ready) begin
            sat_valid <= sum_valid;
        end
    end

    zerochan_round
        #(DW*2-1, DW-1)
    u_round_re
        (clk, round_ready, sat[1], round[1]);

    zerochan_round
        #(DW*2-1, DW-1)
    u_round_im
        (clk, round_ready, sat[0], round[0]);

    always_ff @(posedge clk) begin
        if (rst) begin
            round_valid <= 0;
        end else if (round_ready) begin
            round_valid <= sat_valid;
        end
    end

endmodule : zerochan_rx_tde

module zerochan_rx_ps #
( parameter int DW = 12
)
( input  logic                 clk
, input  logic                 rst

, input  logic signed          s_valid
, output logic signed          s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im
);

    logic signed [DW-1:0] taps [2][21];
    logic signed [DW:0] fold [2][11];
    logic signed [DW+9:0] weight [2][11];
    logic signed [DW+10:0] sum0 [2][4];
    logic signed [DW+10:0] sum1 [2];

    logic ce;

    logic taps_valid;
    logic fold_valid;
    logic product_valid;
    logic sum0_valid;
    logic sum1_valid;

    assign m_valid = sum1_valid;
    assign s_ready = !m_valid || m_ready;

    assign ce = s_ready;

    assign m_re = $signed(sum1[0][DW+8-:DW]);
    assign m_im = $signed(sum1[1][DW+8-:DW]);

    always_ff @(posedge clk) begin
        if (rst) begin
            taps <= '{default:'d0};
        end else if (ce) begin
            if (s_valid) begin
                taps[0] <= {s_re, taps[0][0:19]};
                taps[1] <= {s_im, taps[1][0:19]};
            end

            taps_valid <= s_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            for (int i = 0; i < 2; i++) begin
                for (int t = 0; t < 10; t++) begin
                    fold[i][t] <= taps[i][t] + taps[i][20 - t];
                end

                fold[i][10] <= taps[i][10];
            end

            fold_valid <= taps_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            for (int i = 0; i < 2; i++) begin
                weight[i][ 0] <= fold[i][0];
                weight[i][ 1] <= -(fold[i][1] << 2) - fold[i][1];
                weight[i][ 2] <= (fold[i][2] << 3) - (fold[i][2] << 1);
                weight[i][ 3] <= -fold[i][3];
                weight[i][ 4] <= -(fold[i][4] << 4);
                weight[i][ 5] <= (fold[i][5] << 4) + (fold[i][5] << 2) + fold[i][5];
                weight[i][ 6] <= (fold[i][6] << 5) - (fold[i][6] << 2) - fold[i][6];
                weight[i][ 7] <= -(fold[i][7] << 6) - (fold[i][7] << 3) - fold[i][7];
                weight[i][ 8] <= -(fold[i][8] << 5) - (fold[i][8] << 2);
                weight[i][ 9] <= (fold[i][9] << 8) + (fold[i][9] << 5) + (fold[i][9] << 2) - fold[i][9];
                weight[i][10] <= (fold[i][10] << 9);
            end

            product_valid <= fold_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            for (int i = 0; i < 2; i++) begin
                sum0[i][0] <= weight[i][0] + weight[i][1] + weight[i][2];
                sum0[i][1] <= weight[i][3] + weight[i][4] + weight[i][5];
                sum0[i][2] <= weight[i][6] + weight[i][7] + weight[i][8];
                sum0[i][3] <= weight[i][9] + weight[i][10];

                sum1[i] <= sum0[i][0] + sum0[i][1] + sum0[i][2] + sum0[i][3];
            end

            sum0_valid <= product_valid;
            sum1_valid <= sum0_valid;
        end
    end

endmodule : zerochan_rx_ps

module zerochan_rx_timing #
( parameter int DW = 12
, parameter int BL = 512
, parameter int TF = 50
, parameter int SF = 32
, parameter int TM = $clog2(SF+1) + 1
)
( input  logic                 clk
, input  logic                 rst

, input  logic                 s_valid
, output logic                 s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im

, output logic                 o_sync
);

    logic ce;

    logic signed [TM-1:0] rel_re, rel_im;
    logic signed [TM-1:0] abs_re, abs_im;

    logic [TM*2-3:0] rel_mag, abs_mag;
    logic [TM*2-3:0] mag;

    logic sync;
    logic [6:0] guard;

    assign ce = s_valid && s_ready;

    assign s_ready = m_ready;
    assign m_valid = s_valid;
    assign m_re = s_re;
    assign m_im = s_im;

    assign o_sync = sync;

    zerochan_rx_relative_timing
        #(DW, BL, TF, SF)
    u_rel
        (clk, rst, ce, s_re, s_im, rel_re, rel_im);

    zerochan_rx_absolute_timing
        #(DW, TF, SF)
    u_abs
        (clk, ce, s_re, s_im, abs_re, abs_im);

    always_ff @(posedge clk) begin
        if (ce) begin
            rel_mag <= (rel_re * rel_re) + (rel_im * rel_im);
            abs_mag <= (abs_re * abs_re) + (abs_im * abs_im);
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            mag <= rel_mag[TM*2-3-:TM] * abs_mag[TM*2-3-:TM];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sync <= 0;
            guard <= 0;
        end else if (ce) begin
            if (guard == 0 && mag > 'd160) begin
                sync <= 1'b1;
                guard <= 7'd127;
            end else begin
                sync <= 1'b0;
                guard <= guard > 0 ? guard - 'd1 : guard;
            end
        end
    end

endmodule : zerochan_rx_timing

module zerochan_rx_absolute_timing #
( parameter int DW = 12
, parameter int TF = 50
, parameter int SF = 32
, parameter int TM = $clog2(SF+1) + 1

, parameter string TF_INIT = "tf.mem"
)
( input  logic                  clk
, input  logic                  ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic signed [TM-1:0] o_re
, output logic signed [TM-1:0] o_im
);

    logic re_sign, im_sign;

    logic [SF*4-1:0] line;
    logic [SF-1:0] taps_re, taps_im;

    logic [SF-1:0] sf_re, sf_im;

    logic [SF-1:0] rr, ii, ir, ri;
    logic [TM-1:0] u_rr, u_ii, u_ir, u_ri;

    assign re_sign = i_re[DW-1];
    assign im_sign = i_im[DW-1];

    assign rr = taps_re ^ sf_re;
    assign ii = taps_im ^ sf_im;
    assign ir = taps_im ^ sf_re;
    assign ri = taps_re ^ sf_im;

    always_comb begin
        for (int i = 0; i < SF; i++) begin
            taps_re[i] = line[i*4+1];
            taps_im[i] = line[i*4+0];
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            line <= {line[SF*4-3:0], {re_sign, im_sign}};
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            u_rr <= $countones(rr);
            u_ii <= $countones(ii);
            u_ir <= $countones(ir);
            u_ri <= $countones(ri);
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            o_re <= TM'(SF) - u_rr - u_ii;
            o_im <= u_ri - u_ir;
        end
    end

    initial begin
        var logic [1:0] sf [TF];
        $readmemb(TF_INIT, sf);

        for (int i = 0; i < SF; i++) begin
            sf_re[i] = sf[SF-1-i][1];
            sf_im[i] = sf[SF-1-i][0];
        end
    end

endmodule : zerochan_rx_absolute_timing

module zerochan_rx_relative_timing #
( parameter int DW = 12
, parameter int BL = 512
, parameter int TF = 50
, parameter int SF = 32

, parameter int TM = $clog2(SF+1) + 1
)
( input  logic                  clk
, input  logic                  rst
, input  logic                  ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic signed [TM-1:0] o_re
, output logic signed [TM-1:0] o_im
);

    localparam int LEN = BL - (TF - SF);

    logic [LEN*4-1:0] line;

    logic re_sign, im_sign;
    logic rr, ii, ir, ri;

    logic signed [1:0] p_re, p_im;

    logic [SF*8-1:0] window;

    assign re_sign = i_re[DW-1];
    assign im_sign = i_im[DW-1];

    assign rr = re_sign ^ line[1];
    assign ii = im_sign ^ line[0];
    assign ir = im_sign ^ line[1];
    assign ri = re_sign ^ line[0];

    assign p_re = $signed({rr & ii, rr ~^ ii});
    assign p_im = $signed({ir & ~ri, ir ^ ri});

    always_ff @(posedge clk) begin
        if (ce) begin
            line <= {{re_sign, im_sign}, line[LEN*4-1:2]};
        end
    end

    logic sel;

    logic signed [TM-1:0] acc_re [2];
    logic signed [TM-1:0] acc_im [2];

    always_ff @(posedge clk) begin
        if (rst) begin
            sel <= 0;

            acc_re <= '{default:0};
            acc_im <= '{default:0};
        end else if (ce) begin
            window <= {{p_re, p_im}, window[SF*8-1:4]};

            acc_re[sel] <= acc_re[sel] - $signed(window[3:2]) + p_re;
            acc_im[sel] <= acc_im[sel] - $signed(window[1:0]) + p_im;

            sel <= ~sel;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            o_re <= acc_re[sel];
            o_im <= acc_im[sel];
        end
    end

endmodule : zerochan_rx_relative_timing

module zerochan_rx_mixer #
( parameter int DW = 12
, parameter int AW = 16

, parameter int LUT_WIDTH = 16
, parameter int LUT_DEPTH = 10
)
( input  logic                 clk
, input  logic                 rst

, input  logic        [AW-1:0] i_vel

, input  logic                 s_valid
, output logic                 s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [  DW:0] m_re
, output logic signed [  DW:0] m_im
);

    localparam logic [LUT_DEPTH-1:0] MAX_ADDR = (2 ** LUT_DEPTH) - 1;
    localparam int FW = LUT_WIDTH + 1;

    logic [LUT_WIDTH-1:0] lut [2**LUT_DEPTH];

    logic [AW-1:0] acc;

    logic [1:0] quadrant;
    logic [LUT_DEPTH-1:0] sin_addr;
    logic [LUT_DEPTH-1:0] cos_addr;

    logic signed [FW-1:0] sin, cos;

    logic [3:0] valid;

    assign m_valid = valid[3];
    assign s_ready = !m_valid || m_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            acc <= 0;
        end else if (s_valid && s_ready) begin
            acc <= acc + i_vel;
        end
    end

    always_ff @(posedge clk) begin
        if (s_valid && s_ready) begin
            quadrant <= acc[AW-1-:2];
            sin_addr <= acc[AW-3-:LUT_DEPTH];
            cos_addr <= MAX_ADDR - acc[AW-3-:LUT_DEPTH];
        end
    end

    always_ff @(posedge clk) begin
        if (s_valid && s_ready) begin
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
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            valid <= 0;
        end else if (s_ready) begin
            valid[0] <= s_valid;
            valid[1] <= valid[0];
            valid[2] <= valid[1];
            valid[3] <= valid[2];
        end
    end

    zerochan_mult #
    ( .A(DW)
	, .B(FW)
	, .R(FW-1)
    ) u_mult
    ( .clk(clk)
    , .ce(s_ready)

    , .a_re(s_re)
    , .a_im(s_im)

    , .b_re(cos)
    , .b_im(sin)

    , .o_re(m_re)
	, .o_im(m_im)
    );

    initial begin : init_lut
        int i;

        for (i = 0; i < 2**LUT_DEPTH; i++) begin : gen_lut
           var automatic real theta;

           theta = ($atan(1.0) * 2) / (2**LUT_DEPTH) * real'(i);
           lut[i] = lut_scale($sin(theta));
        end
    end

    function automatic [LUT_WIDTH-1:0] lut_scale(real x);
        localparam int MAX = ((1 << LUT_WIDTH) - 1);

        var automatic real scaled = x * (1 << LUT_WIDTH);
        var automatic int v = $rtoi(scaled + 0.5);

        if (v > MAX) v = MAX;

        return v;
    endfunction

endmodule : zerochan_rx_mixer

module zerochan_rx_sampler #
( parameter int DW = 16
, parameter int BL = 512
, parameter int TF = 32
)
( input  logic                 clk
, input  logic                 rst

, input  logic                 i_sync

, input  logic                 s_valid
, output logic                 s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im
);

    localparam int unsigned W = $clog2(BL * 2);
    localparam int unsigned DF = (BL - TF) * 2;

    logic [W-1:0] cnt;

    assign s_ready = m_ready || cnt[0];
    assign m_valid = s_valid && ~cnt[0] && cnt < DF;

    assign m_re = s_re;
    assign m_im = s_im;

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= 0;
        end else begin
            if (s_ready && s_valid) begin
                if (cnt == W'(BL*2-1)) begin
                    cnt <= 0;
                end else begin
                    cnt <= W'(cnt + 1'd1);
                end
            end

            if (i_sync) begin
                cnt <= W'(BL * 2 - 1);
            end
        end
    end

endmodule : zerochan_rx_sampler
