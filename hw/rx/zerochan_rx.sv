module zerochan_rx #
( parameter int INPUT_WIDTH = 12
, parameter int FFT_N = 1024
, parameter int CP = 61

, parameter int PILOT_SPACING = 16
, parameter int PILOT_OFFSET = 8
)
( input  logic                 clk
, input  logic                 rst

, input  logic [INPUT_WIDTH:0] i_re
, input  logic [INPUT_WIDTH:0] i_im

, output logic                 o_valid
, output logic [          9:0] o_idx
, output logic [          9:0] o_re
, output logic [          9:0] o_im
);

    localparam int FFT_STAGES = $clog2(FFT_N);
    localparam int INDEX_WIDTH = FFT_STAGES;
    localparam int FFT_WIDTH = INPUT_WIDTH + FFT_STAGES;

    logic [INDEX_WIDTH:0] sync_idx;
    logic [INDEX_WIDTH-1:0] fft_idx, comm_idx, eq_idx;
    logic [INPUT_WIDTH-1:0] sync_re, sync_im;
    logic [FFT_WIDTH-1:0] fft_re, fft_im;
    logic [17:0] comm_re, comm_im;
    logic [18*2-1:0] comm_est [4];
    logic [15:0] eq_re, eq_im;

    logic eq_valid;

    logic ce;

    always_ff @(posedge clk) begin
        if (ce) begin
            o_valid <= eq_valid;
            o_idx <= eq_idx;
            o_re <= eq_re;
            o_im <= eq_im;
        end else begin
            o_valid <= 1'b0;
        end
    end

    zerochan_rx_sync #
    ( .DW(INPUT_WIDTH)
    , .N(FFT_N)
    , .CP(CP)
    ) u_sync
    ( .clk(clk)
    , .rst(rst)

    , .i_re(i_re)
    , .i_im(i_im)

    , .o_idx(sync_idx)
    , .o_re(sync_re)
    , .o_im(sync_im)
    );

    zerochan_lib_fft_driver #
    ( .INPUT_WIDTH(INPUT_WIDTH)
    , .FFT_N(FFT_N)
    ) u_fft
    ( .clk(clk)

    , .i_idx(sync_idx)
    , .i_re(sync_re)
    , .i_im(sync_im)

    , .o_ce(ce)
    , .o_idx(fft_idx)
    , .o_re(fft_re)
    , .o_im(fft_im)
    );

    zerochan_rx_commutator #
    ( .FFT_N(FFT_N)
    , .INPUT_WIDTH(FFT_WIDTH)
    , .OUTPUT_WIDTH(18)

    , .PILOT_SPACING(PILOT_SPACING)
    , .PILOT_OFFSET(PILOT_OFFSET)
    ) u_commutator
    ( .clk(clk)
    , .i_ce(ce)

    , .i_idx(fft_idx)
    , .i_re(fft_re)
    , .i_im(fft_im)

    , .o_idx(comm_idx)
    , .o_re(comm_re)
    , .o_im(comm_im)
    , .o_est(comm_est)
    );

    zerochan_rx_eq #
    ( .FFT_N(FFT_N)
    , .INPUT_WIDTH(18)
    , .OUTPUT_WIDTH(10)
    , .PILOT_SPACING(PILOT_SPACING)
    , .PILOT_OFFSET(PILOT_OFFSET)
    ) u_eq
    ( .clk(clk)
    , .i_ce(ce)

    , .i_idx(comm_idx)
    , .i_est(comm_est)
    , .i_re(comm_re)
    , .i_im(comm_im)

    , .o_valid(eq_valid)
    , .o_idx(eq_idx)
    , .o_re(eq_re)
    , .o_im(eq_im)
    );

endmodule : zerochan_rx
