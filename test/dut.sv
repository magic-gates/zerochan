module dut
( input  logic               clk
, input  logic               rst

, input  logic               tx_s_valid
, output logic               tx_s_ready
, input  logic signed [11:0] tx_s_re
, input  logic signed [11:0] tx_s_im

, output logic               tx_m_valid
, input  logic               tx_m_ready
, output logic signed [11:0] tx_m_re
, output logic signed [11:0] tx_m_im

, input  logic               rx_ce

, input  logic signed [11:0] rx_s_re
, input  logic signed [11:0] rx_s_im

, output logic               rx_m_valid
, input  logic signed [11:0] rx_m_re
, input  logic signed [11:0] rx_m_im
);

    zerochan_tx #
    ( .DW(12)
    , .DATA_LEN(480)
    , .UW_LEN(32)
    , .UW_INIT("uw.mem")
    ) u_tx
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(tx_s_valid)
    , .s_ready(tx_s_ready)
    , .s_re(tx_s_re)
    , .s_im(tx_s_im)

    , .m_valid(tx_m_valid)
    , .m_ready(tx_m_ready)
    , .m_re(tx_m_re)
    , .m_im(tx_m_im)
    );

    zerochan_rx #
    ( .DW(12)
    ) u_rx
    ( .clk(clk)
    , .rst(rst)
    , .ce(rx_ce)

    , .s_re(rx_s_re)
    , .s_im(rx_s_im)

    , .m_valid(rx_m_valid)
    , .m_re(rx_m_re)
    , .m_im(rx_m_im)
    );

endmodule : dut
