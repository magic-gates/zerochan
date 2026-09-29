module zerochan_tx_top
( input         clk

, input         i_valid
, output        o_ready
, output [ 9:0] o_idx

, input  [ 9:0] i_re
, input  [ 9:0] i_im

, output [11:0] o_re
, output [11:0] o_im
);

    zerochan_tx u_tx
        (clk, i_valid, o_ready, o_idx, i_re, i_im, o_re, o_im);

endmodule
