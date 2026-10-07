// Root-Raised-Cosine x2 polyphase filter
// roll-off = 0.3
// span = 10
// sps = 2
module zerochan_ps_tx #
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
            weight1[0] <= -(fold1[0] << 2);
            weight0[1] <= (fold0[1] << 2);
            weight1[1] <= -fold1[1];
            weight0[2] <= -(fold0[2] << 4) + (fold0[2] << 2);
            weight1[2] <= (fold1[2] << 4);
            weight0[3] <= (fold0[3] << 4) + (fold0[3] << 2);
            weight1[3] <= -(fold1[3] << 6) + (fold1[3] << 3);
            weight0[4] <= -(fold0[4] << 5) + (fold0[4] << 2) + fold0[4];
            weight1[4] <= (fold1[4] << 8) - (fold1[4] << 5) - fold1[4];
            weight0[5] <= (fold0[5] << 9) - (fold0[5] << 7) + (fold0[5] << 3);

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
            matrix[wr_bank][tag_3] <= {sum1[DW+9-:DW], sum0[DW+9-:DW]};

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

endmodule : zerochan_ps_tx

// Root-Raised-Cosine rx matched filter
// roll-off = 0.3
// span = 10
// sps = 2
module zerochan_ps_rx #
( parameter int DW = 12
)
( input  logic                 clk
, input  logic                 rst
, input  logic                 ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic signed [DW-1:0] o_re
, output logic signed [DW-1:0] o_im
);

    logic signed [DW-1:0] taps [2][21];
    logic signed [DW:0] fold [2][11];
    logic signed [DW+9:0] weight [2][11];
    logic signed [DW+10:0] sum0 [2][4];
    logic signed [DW+10:0] sum1 [2];

    assign o_re = $signed(sum1[0][DW+8-:DW]);
    assign o_im = $signed(sum1[1][DW+8-:DW]);

    always_ff @(posedge clk) begin
        if (rst) begin
            taps <= '{default:'d0};
        end else if (ce) begin
            taps[0] <= {i_re, taps[0][0:19]};
            taps[1] <= {i_im, taps[1][0:19]};
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
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            for (int i = 0; i < 2; i++) begin

                weight[i][ 0] <= fold[i][0];
                weight[i][ 1] <= -(fold[i][1] << 2);
                weight[i][ 2] <= (fold[i][2] << 2);
                weight[i][ 3] <= -fold[i][3];
                weight[i][ 4] <= -(fold[i][4] << 4) + (fold[i][4] << 2);
                weight[i][ 5] <= (fold[i][5] << 4);
                weight[i][ 6] <= (fold[i][6] << 4) + (fold[i][6] << 2);
                weight[i][ 7] <= -(fold[i][7] << 6) + (fold[i][7] << 3);
                weight[i][ 8] <= -(fold[i][8] << 5) + (fold[i][8] << 2) + fold[i][8];
                weight[i][ 9] <= (fold[i][9] << 8) - (fold[i][9] << 5) - fold[i][9];
                weight[i][10] <= (fold[i][10] << 9) - (fold[i][10] << 7) + (fold[i][10] << 3);
            end
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
        end
    end

endmodule : zerochan_ps_rx
