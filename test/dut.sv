`timescale 1ns / 1ps

module dut
( input  logic               clk
, input  logic               arst

, input  logic               i_tx_valid
, output logic               o_tx_ready
, input  logic signed [11:0] i_tx_re
, input  logic signed [11:0] i_tx_im

, output logic signed [11:0] o_loop_re
, output logic signed [11:0] o_loop_im

, input  logic signed [11:0] i_loop_re
, input  logic signed [11:0] i_loop_im

, output logic               o_rx_valid
, output logic        [ 9:0] o_rx_idx
, output logic signed [ 9:0] o_rx_re
, output logic signed [ 9:0] o_rx_im
);

    logic rst;

    magrx_rst u_rst (clk, arst, rst);

    zerochan_tx u_tx_dut
    ( .clk(clk)

    , .i_valid(i_tx_valid)
    , .o_ready(o_tx_ready)
    , .o_idx()

    , .i_re(i_tx_re)
    , .i_im(i_tx_im)

    , .o_re(o_loop_re)
    , .o_im(o_loop_im)
    );

    zerochan_rx u_rx_dut
    ( .clk(clk)
    , .rst(rst)

    , .i_re(i_loop_re)
    , .i_im(i_loop_im)

    , .o_valid(o_rx_valid)
    , .o_idx(o_rx_idx)
    , .o_re(o_rx_re)
    , .o_im(o_rx_im)
    );

    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, dut);
    end

endmodule
