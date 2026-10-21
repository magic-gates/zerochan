module zerochan_tx_top #
( parameter DW = 12
, parameter DF_LEN = 480
, parameter TF_LEN = 48

, parameter TF_INIT = "tf.mem"
)
( input                  clk
, input                  rst

, input                  s_valid
, output                 s_ready
, input  signed [DW-1:0] s_re
, input  signed [DW-1:0] s_im

, output                 m_valid
, input                  m_ready
, output signed [DW-1:0] m_re
, output signed [DW-1:0] m_im
);

    zerochan_tx #(DW, DF_LEN, TF_LEN) u_tx
    (clk, rst, s_valid, s_ready, s_re, s_im, m_valid, m_ready, m_re, m_im);

endmodule
