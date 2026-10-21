module zerochan_tx #
( parameter int unsigned DW = 12
, parameter int unsigned DF_LEN = 480
, parameter int unsigned TF_LEN = 32

, parameter string TF_INIT = "uw.mem"
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
);

    localparam int DF_C = $clog2(DF_LEN);
    localparam int UW_C = $clog2(TF_LEN);

    localparam logic signed [DW-1:0] DW_P = $signed({1'b0, {(DW-1){1'b1}}});
    localparam logic signed [DW-1:0] DW_N = $signed({1'b1, {(DW-2){1'b0}}, 1'b1});

    logic signed [DW-1:0] ps_re, ps_im;
    logic ps_valid, ps_ready;

    logic [1:0] tf_rom [TF_LEN];

    enum logic { DF, TF } state;

    logic [DF_C-1:0] df_cnt;
    logic [UW_C-1:0] tf_cnt;

    logic signed [DW-1:0] tf_re, tf_im;

    initial $readmemb(TF_INIT, tf_rom);

    always_comb begin
        unique case (tf_rom[tf_cnt])
            2'b00: {tf_re, tf_im} = {DW_P, DW_P};
            2'b01: {tf_re, tf_im} = {DW_P, DW_N};
            2'b10: {tf_re, tf_im} = {DW_N, DW_P};
            2'b11: {tf_re, tf_im} = {DW_N, DW_N};
        endcase
    end

    always_comb begin
        if (state == DF) begin
            s_ready = ps_ready;
            ps_valid = s_valid;
            {ps_re, ps_im} = {s_re, s_im};
        end else begin
            s_ready = 1'b0;
            ps_valid = 1'b1;
            {ps_re, ps_im} = {tf_re, tf_im};
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            df_cnt <= 0;
            tf_cnt <= 0;
            state <= DF;
        end else unique case (state)
            DF: if (ps_valid && ps_ready) begin
                if (df_cnt == DF_C'(DF_LEN - 1)) begin
                    state <= TF;
                    df_cnt <= 0;
                end else begin
                    df_cnt <= DF_C'(df_cnt + 'd1);
                end
            end
            TF: if (ps_valid && ps_ready) begin
                if (tf_cnt == UW_C'(TF_LEN - 1)) begin
                    state <= DF;
                    tf_cnt <= 0;
                end else begin
                    tf_cnt <= UW_C'(tf_cnt + 'd1);
                end
            end
        endcase
    end

    zerochan_tx_ps #(DW) u_ps
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(ps_valid)
    , .s_ready(ps_ready)
    , .s_re(ps_re)
    , .s_im(ps_im)

    , .m_valid(m_valid)
    , .m_ready(m_ready)
    , .m_re(m_re)
    , .m_im(m_im)
    );

endmodule : zerochan_tx

module zerochan_tx_ps #
( parameter int DW = 12
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
);

    typedef enum logic { RE, IM } t_tag;

    logic taps_ready, taps_valid;

    logic signed [DW-1:0] taps_re [11];
    logic signed [DW-1:0] taps_im [11];

    t_tag tag;

    logic signed [DW-1:0] taps0 [11];
    logic signed [DW-1:0] taps1 [10];

    logic fold_ready, fold_valid;

    t_tag tag_1;

    logic signed [DW:0] fold0 [6];
    logic signed [DW:0] fold1 [5];

    logic weight_ready, weight_valid;

    t_tag tag_2;

    logic signed [DW+9:0] weight0 [6];
    logic signed [DW+9:0] weight1 [5];

    logic sum_ready, sum_valid;

    t_tag tag_3;

    logic signed [DW+9:0] sum0;
    logic signed [DW+9:0] sum1;

    logic transpose_ready, transpose_valid;

    logic [1:0][DW-1:0] matrix [2][2];

    logic [1:0] bank_full;
    logic wr_bank, rd_bank;
    logic rd_col;

    assign taps0 = tag == RE ? taps_re[0:10] : taps_im[0:10];
    assign taps1 = tag == RE ? taps_re[0:9] : taps_im[0:9];

    assign transpose_valid = bank_full[rd_bank];

    assign taps_ready = fold_ready && (!taps_valid || (tag == IM));
    assign fold_ready = (!fold_valid || weight_ready);
    assign weight_ready = (!weight_valid || sum_ready);
    assign sum_ready = (!sum_valid || transpose_ready);
    assign transpose_ready = ~bank_full[wr_bank];

    assign s_ready = taps_ready;
    assign m_valid = transpose_valid;

    assign m_re = $signed(matrix[rd_bank][0][rd_col]);
    assign m_im = $signed(matrix[rd_bank][1][rd_col]);

    always_ff @(posedge clk) begin
        if (rst) begin
            taps_re <= '{default:0};
            taps_im <= '{default:0};

            tag <= RE;
            taps_valid <= 0;
        end else if (fold_ready) begin
            if (taps_valid && tag == RE) begin
                tag <= IM;
            end else if (s_valid) begin
                taps_re <= {s_re, taps_re[0:9]};
                taps_im <= {s_im, taps_im[0:9]};

                tag <= RE;
                taps_valid <= 1'b1;
            end else begin
                tag <= RE;
                taps_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            fold_valid <= 0;
        end else if (fold_ready) begin
            fold_valid <= taps_valid;

            for (int i = 0; i < 5; i++) begin
                fold0[i] <= taps0[i] + taps0[10 - i];
                fold1[i] <= taps1[i] + taps1[9 - i];
            end

            fold0[5] <= taps0[5];

            tag_1 <= tag;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            weight_valid <= 0;
        end else if (weight_ready) begin
            weight_valid <= fold_valid;

            weight0[0] <= fold0[0];
            weight1[0] <= -(fold1[0] << 2) + fold1[0];
            weight0[1] <= (fold0[1] << 2);
            weight1[1] <= 0;
            weight0[2] <= -(fold0[2] << 3) - (fold0[2] << 1);
            weight1[2] <= (fold1[2] << 4) - (fold1[2] << 1);
            weight0[3] <= (fold0[3] << 4) + (fold0[3] << 1);
            weight1[3] <= -(fold1[3] << 6) + (fold1[3] << 4);
            weight0[4] <= -(fold0[4] << 5) + (fold0[4] << 3) + fold0[4];
            weight1[4] <= (fold1[4] << 8) - (fold1[4] << 6) - fold1[4];
            weight0[5] <= (fold0[5] << 8) + (fold0[5] << 6) + (fold0[5] << 4);

            tag_2 <= tag_1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sum_valid <= 0;
        end else if (sum_ready) begin
            sum_valid <= weight_valid;

            sum0 <= weight0[0] + weight0[1] + weight0[2] + weight0[3] + weight0[4] + weight0[5];
            sum1 <= weight1[0] + weight1[1] + weight1[2] + weight1[3] + weight1[4];

            tag_3 <= tag_2;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_bank <= 0;
        end else if (transpose_ready && sum_valid) begin
            matrix[wr_bank][tag_3] <= {sum1[DW+8-:DW], sum0[DW+8-:DW]};

            if (tag_3 == IM) begin
                wr_bank <= ~wr_bank;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_bank <= 0;
            rd_col <= 0;
        end else if (m_valid && m_ready) begin
            if (rd_col == 1'b1) begin
                rd_col <= 1'b0;
                rd_bank <= ~rd_bank;
            end else begin
                rd_col <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            bank_full <= 2'b00;
        end else begin
            if (transpose_ready && sum_valid && tag_3 == IM) begin
                bank_full[wr_bank] <= 1'b1;
            end

            if (m_ready && m_valid && rd_col == 1'b1) begin
                bank_full[rd_bank] <= 1'b0;
            end
        end
    end

endmodule : zerochan_tx_ps
