module zerochan_rx_top
( input         clk
, input         rst

, input  [11:0] i_re
, input  [11:0] i_im

, output        o_valid
, output [ 9:0] o_idx
, output [ 9:0] o_re
, output [ 9:0] o_im
);

    zerochan_rx u_rx (clk, rst, i_re, i_im, o_valid, o_idx, o_re, o_im);

endmodule
