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

, input  logic               rx_s_valid
, output logic               rx_s_ready
, input  logic signed [11:0] rx_s_re
, input  logic signed [11:0] rx_s_im

, output logic               rx_m_valid
, input  logic               rx_m_ready
, output logic signed [15:0] rx_m_re
, output logic signed [15:0] rx_m_im
);

    zerochan_tx #
    ( .DW(12)
    , .DF_LEN(480)
    , .TF_LEN(48)
    , .TF_INIT("tf.mem")
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

    , .s_axis_tvalid(rx_s_valid)
    , .s_axis_tready(rx_s_ready)
    , .s_axis_tdata({rx_s_re, rx_s_im})

    , .m_axis_tvalid(rx_m_valid)
    , .m_axis_tready(rx_m_ready)
    , .m_axis_tdata({rx_m_re, rx_m_im})
    , .m_axis_tuser()
    );

    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, dut);
    end

endmodule : dut
