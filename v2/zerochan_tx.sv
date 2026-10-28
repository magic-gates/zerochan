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

    localparam int C = $clog2(DF_LEN + TF_LEN);

    logic [C-1:0] cnt;

    logic tf;

    logic tf_valid, tf_ready;
    logic signed [DW-1:0] tf_re, tf_im;

    logic zi_valid, zi_ready;
    logic signed [DW-1:0] zi_re, zi_im;

    assign tf = cnt >= C'(DF_LEN);

    assign zi_valid = tf ? tf_valid : s_valid;
    assign tf_ready = tf ? zi_ready : 1'b0;
    assign s_ready = tf ? 1'b0 : zi_ready;

    assign zi_re = tf ? tf_re : s_re;
    assign zi_im = tf ? tf_im : s_im;

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= 0;
        end else if (zi_valid && zi_ready) begin
            cnt <= cnt == C'(DF_LEN + TF_LEN - 1) ? 0 : C'(cnt + 'd1);
        end
    end

    zerochan_tx_training_field #
    ( .DW(DW)
    , .LEN(TF_LEN)
    , .INIT(TF_INIT)
    ) u_tf
    ( .clk(clk)
    , .rst(rst)

    , .m_valid(tf_valid)
    , .m_ready(tf_ready)
    , .m_re(tf_re)
    , .m_im(tf_im)
    );

    zerochan_tx_zero_insert #(DW) u_zi
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(zi_valid)
    , .s_ready(zi_ready)
    , .s_re(zi_re)
    , .s_im(zi_im)

    , .m_valid(m_valid)
    , .m_ready(m_ready)
    , .m_re(m_re)
    , .m_im(m_im)
    );

endmodule : zerochan_tx

module zerochan_tx_zero_insert #
( parameter int unsigned DW = 12
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

    logic zero;

    assign s_ready = (!m_valid || m_ready) && !zero;

    always_ff @(posedge clk) begin
        if (rst) begin
            zero <= 0;
            m_valid <= 0;
        end else if (s_ready) begin
            m_valid <= s_valid;

            m_re <= s_re;
            m_im <= s_im;

            zero <= s_valid;
        end else if (zero) begin
            m_valid <= 1'b1;

            m_re <= 0;
            m_im <= 0;

            zero <= 1'b0;
        end
    end

endmodule : zerochan_tx_zero_insert

module zerochan_tx_training_field #
( parameter int unsigned DW = 12
, parameter int unsigned LEN = 32

, parameter string INIT = "uw.mem"
)
( input  logic                 clk
, input  logic                 rst

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im
);

    localparam int AW = $clog2(LEN);

    localparam logic signed [DW-1:0] P = $signed({1'b0, {(DW-1){1'b1}}});
    localparam logic signed [DW-1:0] N = $signed({1'b1, {(DW-2){1'b0}}, 1'b1});

    logic [1:0] rom [LEN];
    initial $readmemb(INIT, rom);

    logic [AW-1:0] addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            addr <= 0;
            m_valid <= 1'b0;
        end else begin
            m_valid <= 1'b1;

            unique case (rom[addr])
                2'b00: {m_re, m_im} <= {P, P};
                2'b01: {m_re, m_im} <= {P, N};
                2'b10: {m_re, m_im} <= {N, P};
                2'b11: {m_re, m_im} <= {N, N};
            endcase

            if (m_ready) begin
                addr <= AW'(addr + 'd1);
            end
        end
    end

endmodule : zerochan_tx_training_field

// module zerochan_tx #
// ( parameter int unsigned DW = 12
// , parameter int unsigned DF_LEN = 480
// , parameter int unsigned TF_LEN = 32
//
// , parameter string TF_INIT = "uw.mem"
// )
// ( input  logic                 clk
// , input  logic                 rst
//
// , input  logic                 s_valid
// , output logic                 s_ready
// , input  logic signed [DW-1:0] s_re
// , input  logic signed [DW-1:0] s_im
//
// , output logic                 m_valid
// , input  logic                 m_ready
// , output logic signed [DW-1:0] m_re
// , output logic signed [DW-1:0] m_im
// );
//
//     localparam int DF_C = $clog2(DF_LEN);
//     localparam int UW_C = $clog2(TF_LEN);
//
//     localparam logic signed [DW-1:0] DW_P = $signed({1'b0, {(DW-1){1'b1}}});
//     localparam logic signed [DW-1:0] DW_N = $signed({1'b1, {(DW-2){1'b0}}, 1'b1});
//
//     logic signed [DW-1:0] ps_re, ps_im;
//     logic ps_valid, ps_ready;
//
//     logic [1:0] tf_rom [TF_LEN];
//
//     enum logic { DF, TF } state;
//
//     logic [DF_C-1:0] df_cnt;
//     logic [UW_C-1:0] tf_cnt;
//
//     logic signed [DW-1:0] tf_re, tf_im;
//
//     initial $readmemb(TF_INIT, tf_rom);
//
//     always_comb begin
//         unique case (tf_rom[tf_cnt])
//             2'b00: {tf_re, tf_im} = {DW_P, DW_P};
//             2'b01: {tf_re, tf_im} = {DW_P, DW_N};
//             2'b10: {tf_re, tf_im} = {DW_N, DW_P};
//             2'b11: {tf_re, tf_im} = {DW_N, DW_N};
//         endcase
//     end
//
//     always_comb begin
//         if (state == DF) begin
//             s_ready = ps_ready;
//             ps_valid = s_valid;
//             {ps_re, ps_im} = {s_re, s_im};
//         end else begin
//             s_ready = 1'b0;
//             ps_valid = 1'b1;
//             {ps_re, ps_im} = {tf_re, tf_im};
//         end
//     end
//
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             df_cnt <= 0;
//             tf_cnt <= 0;
//             state <= DF;
//         end else unique case (state)
//             DF: if (ps_valid && ps_ready) begin
//                 if (df_cnt == DF_C'(DF_LEN - 1)) begin
//                     state <= TF;
//                     df_cnt <= 0;
//                 end else begin
//                     df_cnt <= DF_C'(df_cnt + 'd1);
//                 end
//             end
//             TF: if (ps_valid && ps_ready) begin
//                 if (tf_cnt == UW_C'(TF_LEN - 1)) begin
//                     state <= DF;
//                     tf_cnt <= 0;
//                 end else begin
//                     tf_cnt <= UW_C'(tf_cnt + 'd1);
//                 end
//             end
//         endcase
//     end
//
// endmodule : zerochan_tx
