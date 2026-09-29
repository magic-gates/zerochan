module zerochan_rx_sync #
( parameter int DW = 12
, parameter int N = 1024
, parameter int CP = 64

, parameter int ANGLE = 16
, parameter int CC_STAGES = 16
, parameter int LOOP_KP = 3
, parameter int LOOP_KI = 8
, parameter int MX_LUT_DEPTH = 12
, parameter int MX_LUT_WIDTH = DW + 2

, parameter int LEN = N + CP
, parameter int ID = $clog2(LEN)
)
( input  logic                 clk
, input  logic                 rst

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic        [ID-1:0] o_idx
, output logic signed [DW-1:0] o_re
, output logic signed [DW-1:0] o_im
);

    /* Sample counter */

    logic [ID-1:0] idx;

    wire [ID-1:0] mod = ID'(LEN - 1) + $signed({err_early, err_early | err_late});
    wire idx_wrap = idx == mod;

    assign o_idx = mx_idx_3;

    always_ff @(posedge clk) begin
        if (rst) begin
            idx <= 0;
        end else if (idx_wrap) begin
            idx <= 0;
        end else begin
            idx <= idx + ID'(1);
        end
    end

    /* Digital AGC */

    wire [DW-2:0] agc_re_abs = (i_re < 0) ? (-i_re) : (i_re);
    wire [DW-2:0] agc_im_abs = (i_im < 0) ? (-i_im) : (i_im);
    logic signed [DW-1:0] agc_re, agc_im;
    logic [DW-2:0] agc_value;
    logic [ID-1:0] agc_idx;
    logic idx_wrap_0;

    always_ff @(posedge clk) begin
        agc_value <= agc_re_abs > agc_im_abs ? agc_re_abs : agc_im_abs;
        {agc_re, agc_im} <= {i_re, i_im};
        agc_idx <= idx;
        idx_wrap_0 <= idx_wrap;
    end

    logic [DW-2:0] agc_max;
    logic signed [DW-1:0] agc_re_0, agc_im_0;
    logic [ID-1:0] agc_idx_0;
    logic idx_wrap_1;

    always_ff @(posedge clk) begin
        if (agc_value > agc_max || agc_idx == 0) begin
            agc_max <= agc_value;
        end

        {agc_re_0, agc_im_0} <= {agc_re, agc_im};
        agc_idx_0 <= agc_idx;
        idx_wrap_1 <= idx_wrap_0;
    end

    localparam int GAIN_WIDTH = $clog2(DW);
    localparam int GAIN_ACC_WIDTH = GAIN_WIDTH + 4;

    logic [GAIN_WIDTH-1:0] agc_lzc;
    logic signed [GAIN_ACC_WIDTH-1:0] gain_acc;
    logic signed [DW-1:0] ga_re, ga_im;
    logic [ID-1:0] agc_idx_1;

    wire [GAIN_WIDTH-1:0] gain = gain_acc[GAIN_ACC_WIDTH-1-:GAIN_WIDTH];

    always_comb begin
        agc_lzc = DW - 1;

        for (int i = DW - 2; i >= 0; i--) begin
            if (agc_max[i]) begin
                agc_lzc = DW - 2 - i;
                break;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            gain_acc <= 0;
        end else if (idx_wrap_1) begin
            gain_acc <= gain_acc + (($signed({1'b0, agc_lzc, 4'd0}) - gain_acc) >>> 2);
        end
    end

    always_ff @(posedge clk) begin
        ga_re <= agc_re_0 << gain;
        ga_im <= agc_im_0 << gain;

        agc_idx_1 <= agc_idx_0;
    end

    /* Metric */

    logic [N*2-1:0] line;

    wire d_re = line[1];
    wire d_im = line[0];

    always_ff @(posedge clk) begin
        line <= {{o_re[DW-1], o_im[DW-1]}, line[N*2-1:2]};
    end

    localparam int MW = $clog2(CP) + 2;

    logic [ID-1:0] idx_1;

    logic signed [1:0] p_re, p_im;

    wire rr = o_re[DW-1] ^ d_re;
    wire ii = o_im[DW-1] ^ d_im;
    wire ir = o_im[DW-1] ^ d_re;
    wire ri = o_re[DW-1] ^ d_im;

    always_ff @(posedge clk) begin
        idx_1 <= mx_idx_3;

        p_re <= {rr & ii, rr ~^ ii};
        p_im <= {ir & ~ri, ir ^ ri};
    end

    logic [CP*4-1:0] hist;

    logic signed [MW-1:0] m_re;
    logic signed [MW-1:0] m_im;

    logic [ID-1:0] idx_2;

    always_ff @(posedge clk) begin
        idx_2 <= idx_1;

        hist <= {{p_re, p_im}, hist[CP*4-1:4]};

        m_re <= m_re - $signed(hist[3:2]) + p_re;
        m_im <= m_im - $signed(hist[1:0]) + p_im;
    end

    /* Compute magnitude */

    wire [MW-1:0] m_abs_re = (m_re < 0) ? -m_re : m_re;
    wire [MW-1:0] m_abs_im = (m_im < 0) ? -m_im : m_im;

    logic [MW-1:0] m_re_1, m_im_1;

    logic [MW-1:0] m_abs_re_gt_im;
    logic [ID-1:0] idx_3;

    always_ff @(posedge clk) begin
        m_abs_re_gt_im <= m_abs_re > m_abs_im;
        {m_re_1, m_im_1} <= {m_re, m_im};
        idx_3 <= idx_2;
    end

    wire [MW-1:0] m_abs_max = m_abs_re_gt_im ? m_abs_re : m_abs_im;
    wire [MW-1:0] m_abs_min = m_abs_re_gt_im ? m_abs_im : m_abs_re;

    logic [MW-1:0] m_re_2, m_im_2;

    logic [MW-1:0] m_mag;
    logic [ID-1:0] idx_4;

    always_ff @(posedge clk) begin
        m_mag <= m_abs_max + (m_abs_min >>> 1);
        {m_re_2, m_im_2} <= {m_re_1, m_im_1};
        idx_4 <= idx_3;
    end

    /* Peak search window */

    localparam logic [ID-1:0] BOUNDARY = (LEN / 2) - CP - 1;

    logic signed [MW-1:0] peak_re, peak_im;
    logic [MW-1:0] last_peak;
    logic [ID-1:0] peak_idx;

    wire boundary = mx_idx_3 == BOUNDARY;

    always_ff @(posedge clk) begin
        if (m_mag > last_peak || boundary) begin
            last_peak <= m_mag;
            peak_idx <= idx_4;
            {peak_re, peak_im} <= {m_re_2, m_im_2};
        end
    end

    /* Cordic FSM */

    localparam int SW = $clog2(CC_STAGES);

    logic signed [ANGLE-1:0] atan [CC_STAGES];
    logic signed [ANGLE-1:0] angle;
    logic [SW-1:0] cc_stage;
    logic cc_run;

    logic signed [MW-1:0] cc_re, cc_im;

    logic ffo_ready;

    wire cc_sign = ~cc_im[MW-1];

    wire signed [MW-1:0] re_shr = cc_re >>> cc_stage;
    wire signed [MW-1:0] im_shr = cc_im >>> cc_stage;

    always_ff @(posedge clk) begin
        if (boundary) begin
            unique case ({peak_re[MW-1], peak_im[MW-1]})
                2'b00,
                2'b01: begin
                    cc_re <= peak_re;
                    cc_im <= peak_im;
                    angle <= 0;
                end
                2'b10: begin
                    cc_re <= peak_im;
                    cc_im <= -peak_re;
                    angle <= {2'b01, {ANGLE-2{1'b0}}};
                end
                2'b11: begin
                    cc_re <= -peak_im;
                    cc_im <= peak_re;
                    angle <= {2'b11, {ANGLE-2{1'b0}}};
                end
            endcase

            cc_stage <= 0;
            cc_run <= 1'b1;
        end

        if (cc_run) begin
            if (cc_im == 0) begin
                cc_run <= 1'b0;
                ffo_ready <= 1'b1;
            end else begin
                cc_re <= cc_sign ? cc_re + im_shr : cc_re - im_shr;
                cc_im <= cc_sign ? cc_im - re_shr : cc_im + re_shr;

                angle <= cc_sign ? angle + atan[cc_stage] : angle - atan[cc_stage];

                if (cc_stage == SW'(CC_STAGES - 1)) begin
                    cc_run <= 1'b0;
                    ffo_ready <= 1'b1;
                end else begin
                    cc_stage <= cc_stage + SW'(1);
                end
            end
        end

        if (ffo_ready) begin
            ffo_ready <= 1'b0;
        end
    end

    generate for (genvar i = 0; i < CC_STAGES; i++) begin : gen_atan
        assign atan[i] = int'($atan(2.0 ** -i) / $atan(1.0) * (2.0 ** (ANGLE - 3)));
    end endgenerate

    /* Timing Error */

    // localparam int DEV = ID + 1;

    // localparam logic [ID-1:0] REF = N - 1;
    // localparam logic [ID-1:0] WRAP = (LEN / 2) - CP;
    // localparam logic signed [ID-1:0] HALF = -(N / 2);

    // wire signed [DEV-1:0] base_dev = peak_idx - REF;

    // logic signed [DEV-1:0] dev;
    // logic dev_valid;

    // always_ff @(posedge clk) begin
    //     if (boundary && peak_valid) begin
    //         dev <= base_dev < HALF ? base_dev + LEN : base_dev;
    //     end

    //     dev_valid <= boundary;
    // end

    localparam logic [ID-1:0] REF = (N - 1) + 4;
    localparam logic [ID-1:0] WRAP = (LEN / 2) - CP;

    logic err_late;
    logic err_early;
    logic err_valid;

    always_ff @(posedge clk) begin
        if (boundary) begin
            err_late <= (peak_idx > REF) || (peak_idx <= WRAP - ID'(1));
            err_early <= (peak_idx < REF) && (peak_idx > WRAP);
        end

        err_valid <= boundary;
    end

    // logic signed [ID-1:0] err_acc;
    // wire signed [ID-1:0] err = err_acc[ID-1-:ID];
    // logic err_valid;

    // always_ff @(posedge clk) begin
    //     if (vote_valid) begin
    //         err_acc <= err_acc + $signed({vote_early, vote_late});
    //     end

    //     err_valid <= vote_valid;
    // end

    // logic err_early;
    // logic err_late;

    // always_ff @(posedge clk) begin
    //     if (err_valid) begin
    //         if (err >= 4) begin
    //             err_late <= 1'b1;
    //             err_early <= 1'b0;
    //         end else if (err <= -4) begin
    //             err_late <= 1'b0;
    //             err_early <= 1'b1;
    //         end else begin
    //             err_late <= 1'b0;
    //             err_early <= 1'b0;
    //         end
    //     end
    // end

    // logic vote_late;
    // logic vote_early;
    // logic vote_valid;

    // always_ff @(posedge clk) begin
    //     if (boundary) begin
    //         vote_late <= (peak_idx > REF) || (peak_idx <= WRAP - ID'(1));
    //         vote_early <= (peak_idx < REF) && (peak_idx > WRAP);
    //     end

    //     vote_valid <= boundary;
    // end

    // /* Voting */

    // logic [VOCAP-1:0] early_votes;
    // logic [VOCAP-1:0] late_votes;

    // wire err_early = early_votes[VOCAP-1];
    // wire err_late = late_votes[VOCAP-1];

    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         early_votes <= VOCAP'(1);
    //         late_votes <= VOCAP'(1);
    //     end else if (vote_valid) begin
    //         if (vote_early) begin
    //             if (!err_early) early_votes <= early_votes << 1;
    //             if (!&late_votes[0]) late_votes <= late_votes >> 1;
    //         end else if (vote_late) begin
    //             if (!err_late) late_votes <= late_votes << 1;
    //             if (!&early_votes[0]) early_votes <= early_votes >> 1;
    //         end else begin
    //             if (!&early_votes[1:0]) early_votes <= early_votes >> 1;
    //             if (!&late_votes[1:0]) late_votes <= late_votes >> 1;
    //         end
    //     end
    // end

    /* Loop Filter */

    localparam int LA = ANGLE * 2;

    logic signed [ANGLE-1:0] dbg_angle;
    logic signed [LA-1:0] integral;
    logic signed [LA-1:0] proportional;
    wire signed [LA-1:0] sum = integrator + proportional;

    logic pi_valid_0;

    logic signed [LA-1:0] integrator;
    logic pi_valid_1;

    logic signed [ANGLE-1:0] pi_ffo;
    logic pi_valid;

    always_ff @(posedge clk) begin
        if (ffo_ready) begin
            dbg_angle <= angle;
            integral <= (angle <<< ANGLE) >>> LOOP_KI;
            proportional <= (angle <<< ANGLE) >>> LOOP_KP;
        end

        pi_valid_0 <= ffo_ready;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            integrator <= 0;
        end else if (pi_valid_0) begin
            integrator <= integrator + integral;
        end

        pi_valid_1 <= pi_valid_0;
    end

    always_ff @(posedge clk) begin
        if (pi_valid_1) begin
            pi_ffo <= sum[ANGLE*2-1:ANGLE];
        end

        pi_valid <= pi_valid_1;
    end

    /* Mixer */

    localparam int MX_FRAC = $clog2(N);
    localparam int MX_AW = ANGLE+MX_FRAC;

    logic [MX_LUT_WIDTH-1:0] lut [2**MX_LUT_DEPTH];

    logic signed [ANGLE-1:0] vel;

    always_ff @(posedge clk) begin
        if (rst) begin
            vel <= 0;
        end else if (pi_valid) begin
            vel <= vel - pi_ffo;
        end
    end

    logic signed [MX_AW-1:0] acc;

    always_ff @(posedge clk) begin
        if (rst) begin
            acc <= 0;
        end else begin
            acc <= acc + vel;
        end
    end

    localparam logic [MX_LUT_DEPTH-1:0] MX_LUT_MAX_ADDR = (2 ** MX_LUT_DEPTH) - 1;

    logic [1:0] quadrant;

    logic [MX_LUT_DEPTH-1:0] sin_addr;
    logic [MX_LUT_DEPTH-1:0] cos_addr;

    always_ff @(posedge clk) begin
        quadrant <= acc[MX_AW-1-:2];
        sin_addr <= acc[MX_AW-3-:MX_LUT_DEPTH];
        cos_addr <= MX_LUT_MAX_ADDR - acc[MX_AW-3-:MX_LUT_DEPTH];
    end

    logic [1:0] quadrant_1;

    logic [MX_LUT_WIDTH-1:0] lut_sin, lut_cos;

    always_ff @(posedge clk) begin
        quadrant_1 <= quadrant;
        lut_sin <= lut[sin_addr];
        lut_cos <= lut[cos_addr];
    end

    localparam int FW = MX_LUT_WIDTH + 1;

    logic signed [FW-1:0] cos, sin;

    always_comb begin
        unique case (quadrant_1)
            2'b00: begin
                cos = $signed({1'b0, lut_cos});
                sin = $signed({1'b0, lut_sin});
            end
            2'b01: begin
                cos = -$signed({1'b0, lut_sin});
                sin =  $signed({1'b0, lut_cos});
            end
            2'b10: begin
                cos = -$signed({1'b0, lut_cos});
                sin = -$signed({1'b0, lut_sin});
            end
            2'b11: begin
                cos =  $signed({1'b0, lut_sin});
                sin = -$signed({1'b0, lut_cos});
            end
        endcase
    end

    logic signed [DW:0] mx_s1;
    logic signed [FW:0] mx_s2;
    logic signed [DW:0] mx_s3;

    logic signed [DW-1:0] im_0;
    logic signed [FW-1:0] cos_0, sin_0;

    logic [ID-1:0] mx_idx_0, mx_idx_1, mx_idx_2, mx_idx_3;

    logic signed [DW:0] mx_re, mx_im;

    assign o_re = mx_re[DW-1:0];
    assign o_im = mx_im[DW-1:0];

    always_ff @(posedge clk) begin
        mx_idx_0 <= agc_idx_1;
        mx_idx_1 <= mx_idx_0;
        mx_idx_2 <= mx_idx_1;
        mx_idx_3 <= mx_idx_2;
    end

    zerochan_lib_mult_4
        #(DW, FW, FW-1)
    u_mult
        (clk, 1'b1, ga_re, ga_im, cos, sin, mx_re, mx_im);

    initial begin : gen_mx_lut
        int i;

        for (i = 0; i < 2**MX_LUT_DEPTH; i++) begin
           var automatic real theta;
           var automatic int cos, sin;

           theta = ($atan(1.0) * 2) / (2**MX_LUT_DEPTH) * real'(i);
           sin = mx_lut_scale($sin(theta) * $cos($atan(1.0)));

           lut[i] = sin;
        end
    end

    function automatic [MX_LUT_WIDTH-1:0] mx_lut_scale(real x);
        localparam int MAX = ((1 << MX_LUT_WIDTH) - 1);

        var automatic real scaled = x * (1 << MX_LUT_WIDTH);
        var automatic int v = $rtoi(scaled + 0.5);

        if (v > MAX) v = MAX;

        return v;
    endfunction

endmodule : zerochan_rx_sync
