module zerochan_lib_fft_driver #
( parameter int FFT_N = 1024
, parameter int INPUT_WIDTH = 12
, parameter int OUTPUT_WIDTH = INPUT_WIDTH + $clog2(FFT_N)
, parameter bit INVERSE = 0

, parameter int INDEX_WIDTH = $clog2(FFT_N)
, parameter int INPUT_INDEX = $clog2(FFT_N) + 1
)
( input  logic                    clk

, output logic                    o_ce

, input  logic [ INPUT_INDEX-1:0] i_idx
, output logic [ INDEX_WIDTH-1:0] o_idx

, input  logic [ INPUT_WIDTH-1:0] i_re
, input  logic [ INPUT_WIDTH-1:0] i_im

, output logic [OUTPUT_WIDTH-1:0] o_re
, output logic [OUTPUT_WIDTH-1:0] o_im
);

    logic ce;
    logic [INDEX_WIDTH-1:0] t_idx;
    logic [INPUT_WIDTH-1:0] t_re, t_im;

    logic [INDEX_WIDTH-1:0] f_idx;
    logic [(INPUT_WIDTH+10)-1:0] f_re, f_im;

    always @(posedge clk) begin
        ce <= ~i_idx[INPUT_INDEX-1];
        t_idx <= i_idx[INDEX_WIDTH-1:0];
        t_re <= i_re;
        t_im <= i_im;
    end

    always_ff @(posedge clk) begin
        o_idx <= f_idx;
        o_ce <= ce;

        o_re <= f_re;
        o_im <= f_im;
    end

    zerochan_lib_fft_1024 #
    ( .INPUT_WIDTH(INPUT_WIDTH)
    , .TWIDDLE_WIDTH(18)
    , .INVERSE(INVERSE)
    ) u_fft_1024
    ( .clk(clk)

    , .i_ce(ce)
    , .i_idx(t_idx)
    , .o_idx(f_idx)

    , .i_re(t_re)
    , .i_im(t_im)

    , .o_re(f_re)
    , .o_im(f_im)
    );

endmodule : zerochan_lib_fft_driver

module zerochan_lib_fft_1024 #
( parameter int INPUT_WIDTH = 12
, parameter int TWIDDLE_WIDTH = 16
, parameter bit INVERSE = 0

, parameter int FFT_N = 1024
, parameter int IDX_WIDTH = $clog2(FFT_N)
, parameter int OUTPUT_WIDTH = INPUT_WIDTH + $clog2(FFT_N)
)
( input  logic                    clk

, input  logic                    i_ce
, input  logic [   IDX_WIDTH-1:0] i_idx
, output logic [   IDX_WIDTH-1:0] o_idx

, input  logic [ INPUT_WIDTH-1:0] i_re
, input  logic [ INPUT_WIDTH-1:0] i_im

, output logic [OUTPUT_WIDTH-1:0] o_re
, output logic [OUTPUT_WIDTH-1:0] o_im
);

    localparam int DATA_WIDTH = INPUT_WIDTH;

    logic signed [DATA_WIDTH+1:0] re_0, im_0;
    logic signed [DATA_WIDTH+3:0] re_1, im_1;
    logic signed [DATA_WIDTH+5:0] re_2, im_2;
    logic signed [DATA_WIDTH+7:0] re_3, im_3;
    logic signed [DATA_WIDTH+9:0] re_4, im_4;

    logic [IDX_WIDTH-1:0] idx_0, idx_1, idx_2, idx_3, idx_4;

    zerochan_lib_fft_sdf
        #(FFT_N, 4, DATA_WIDTH + 0, TWIDDLE_WIDTH, INVERSE)
    u_sdf0
        (clk, i_ce, i_idx, idx_0, i_re, i_im, re_0, im_0);

    zerochan_lib_fft_sdf
        #(FFT_N, 3, DATA_WIDTH + 2, TWIDDLE_WIDTH, INVERSE)
    u_sdf1
        (clk, i_ce, idx_0, idx_1, re_0, im_0, re_1, im_1);

    zerochan_lib_fft_sdf
        #(FFT_N, 2, DATA_WIDTH + 4, TWIDDLE_WIDTH, INVERSE)
    u_sdf2
        (clk, i_ce, idx_1, idx_2, re_1, im_1, re_2, im_2);

    zerochan_lib_fft_sdf
        #(FFT_N, 1, DATA_WIDTH + 6, TWIDDLE_WIDTH, INVERSE)
    u_sdf3
         (clk, i_ce, idx_2, idx_3, re_2, im_2, re_3, im_3);

    zerochan_lib_fft_sdf
        #(FFT_N, 0, DATA_WIDTH + 8, TWIDDLE_WIDTH, INVERSE)
    u_sdf4
        (clk, i_ce, idx_3, o_idx, re_3, im_3, o_re, o_im);

endmodule : zerochan_lib_fft_1024

module zerochan_lib_fft_sdf #
( parameter int FFT_N = 16
, parameter int STAGE  = 0
, parameter int DATA_WIDTH = 16
, parameter int TWIDDLE_WIDTH = 16
, parameter bit INVERSE = 0

, parameter int INDEX_WIDTH = $clog2(FFT_N)
, parameter int STRIDE_1 = (4 ** STAGE) * 2
)
( input  logic                   clk

, input  logic                   i_ce
, input  logic [INDEX_WIDTH-1:0] i_idx
, output logic [INDEX_WIDTH-1:0] o_idx

, input  logic [ DATA_WIDTH-1:0] i_re
, input  logic [ DATA_WIDTH-1:0] i_im

, output logic [ DATA_WIDTH+1:0] o_re
, output logic [ DATA_WIDTH+1:0] o_im
);

    logic [DATA_WIDTH+1:0] re_0, im_0;
    logic [INDEX_WIDTH-1:0] idx_0;

    zerochan_lib_fft_rdx4
        #(DATA_WIDTH, INDEX_WIDTH, STRIDE_1, STRIDE_1 / 2, INVERSE)
    u_rdx4
        (clk, i_ce, i_idx, idx_0, i_re, i_im, re_0, im_0);

    generate if (STAGE > 0) begin : gen_twiddle
        zerochan_lib_fft_twiddle
            #(FFT_N, STAGE, DATA_WIDTH + 2, TWIDDLE_WIDTH, INVERSE)
        u_tw
            (clk, i_ce, idx_0, o_idx, re_0, im_0, o_re, o_im);
    end else begin
        assign {o_re, o_im} = {re_0, im_0};
        assign o_idx = idx_0;
    end endgenerate

endmodule : zerochan_lib_fft_sdf

module zerochan_lib_fft_rdx4 #
( parameter int DATA_WIDTH = 16
, parameter int INDEX_WIDTH = 2
, parameter int STRIDE_1 = 1
, parameter int STRIDE_2 = 0
, parameter bit INVERSE = 0
)
( input  logic                   clk

, input  logic                   i_ce
, input  logic [INDEX_WIDTH-1:0] i_idx
, output logic [INDEX_WIDTH-1:0] o_idx

, input  logic [ DATA_WIDTH-1:0] i_re
, input  logic [ DATA_WIDTH-1:0] i_im

, output logic [ DATA_WIDTH+1:0] o_re
, output logic [ DATA_WIDTH+1:0] o_im
);

    logic [DATA_WIDTH:0] bf1_re, bf1_im;
    logic [INDEX_WIDTH-1:0] bf1_idx;

    zerochan_lib_fft_bf1
        #(DATA_WIDTH + 0, INDEX_WIDTH, STRIDE_1)
    u_bf1
        (clk, i_ce, i_idx, bf1_idx, i_re, i_im, bf1_re, bf1_im);

    zerochan_lib_fft_bf2
        #(DATA_WIDTH + 1, INDEX_WIDTH, STRIDE_2, INVERSE)
    u_bf2
        (clk, i_ce, bf1_idx, o_idx, bf1_re, bf1_im, o_re, o_im);

endmodule : zerochan_lib_fft_rdx4

module zerochan_lib_fft_twiddle #
( parameter int FFT_N = 16
, parameter int DEPTH = 0
, parameter int DATA_WIDTH = 16
, parameter int TWIDDLE_WIDTH = 16
, parameter bit INVERSE = 0

, parameter int IDX_WIDTH = $clog2(FFT_N)
, parameter int ADDR_WIDTH = (DEPTH + 1) * 2
)
( input  logic                         clk

, input  logic                         i_ce

, input  logic        [ IDX_WIDTH-1:0] i_idx
, output logic        [ IDX_WIDTH-1:0] o_idx

, input  logic signed [DATA_WIDTH-1:0] i_re
, input  logic signed [DATA_WIDTH-1:0] i_im

, output logic signed [DATA_WIDTH-1:0] o_re
, output logic signed [DATA_WIDTH-1:0] o_im
);

    logic signed [   DATA_WIDTH-1:0] re_1, im_1;
    logic signed [TWIDDLE_WIDTH-1:0] w_re, w_im;

    logic signed [DATA_WIDTH+1:0] r_re, r_im;

    assign o_re = r_re[DATA_WIDTH-1:0];
    assign o_im = r_im[DATA_WIDTH-1:0];

    always_ff @(posedge clk) begin
        if (i_ce) begin
            {re_1, im_1} <= {i_re, i_im};
            o_idx <= i_idx - IDX_WIDTH'(4);
        end
    end

    zerochan_lib_fft_rom
        #(FFT_N, DEPTH, TWIDDLE_WIDTH, INVERSE)
    u_rom
        (clk, i_ce, i_idx[ADDR_WIDTH-1:0], w_re, w_im);

    zerochan_lib_mult_4
        #(DATA_WIDTH, TWIDDLE_WIDTH, TWIDDLE_WIDTH-1)
    u_rotate
        (clk, i_ce, re_1, im_1, w_re, w_im, r_re, r_im);

endmodule : zerochan_lib_fft_twiddle

module zerochan_lib_fft_bf1 #
( parameter int DATA_WIDTH = 16
, parameter int IDX_WIDTH = 10
, parameter int STRIDE = 1
)
( input  logic                         clk
, input  logic                         i_ce

, input  logic        [ IDX_WIDTH-1:0] i_idx
, output logic        [ IDX_WIDTH-1:0] o_idx

, input  logic signed [DATA_WIDTH-1:0] i_re
, input  logic signed [DATA_WIDTH-1:0] i_im

, output logic signed [  DATA_WIDTH:0] o_re
, output logic signed [  DATA_WIDTH:0] o_im
);

    localparam int INTERNAL_WIDTH = DATA_WIDTH + 1;

    wire bottom_edge = i_idx[$clog2(STRIDE)];

    logic signed [INTERNAL_WIDTH-1:0] f_re, f_im;
    logic signed [INTERNAL_WIDTH-1:0] d_re, d_im;

    always_comb begin
        if (bottom_edge) begin
            f_re = d_re - i_re;
            f_im = d_im - i_im;
        end else begin
            f_re = i_re;
            f_im = i_im;
        end
    end

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (bottom_edge) begin
                o_re <= d_re + i_re;
                o_im <= d_im + i_im;
            end else begin
                o_re <= d_re;
                o_im <= d_im;
            end
        end
    end

    always_ff @(posedge clk) begin
       if (i_ce) begin
           o_idx <= i_idx - IDX_WIDTH'(STRIDE);
       end
    end

    zerochan_lib_fft_delay
        #(STRIDE, INTERNAL_WIDTH)
    u_delay
        (clk, i_ce, f_re, f_im, d_re, d_im);

endmodule : zerochan_lib_fft_bf1

module zerochan_lib_fft_bf2 #
( parameter int DATA_WIDTH = 16
, parameter int IDX_WIDTH = 10
, parameter int STRIDE = 1
, parameter bit INVERSE = 0
)
( input  logic                         clk

, input  logic                         i_ce
, input  logic        [ IDX_WIDTH-1:0] i_idx
, output logic        [ IDX_WIDTH-1:0] o_idx

, input  logic signed [DATA_WIDTH-1:0] i_re
, input  logic signed [DATA_WIDTH-1:0] i_im

, output logic signed [  DATA_WIDTH:0] o_re
, output logic signed [  DATA_WIDTH:0] o_im
);

    localparam int INTERNAL_WIDTH = DATA_WIDTH + 1;

    logic signed [INTERNAL_WIDTH-1:0] f_re, f_im;
    logic signed [INTERNAL_WIDTH-1:0] d_re, d_im;

    wire bottom_edge = i_idx[$clog2(STRIDE)];
    wire swap = i_idx[$clog2(STRIDE) + 1] & i_idx[$clog2(STRIDE)];

    always_comb begin
        if (bottom_edge) begin
            if (swap) begin
                if (INVERSE) begin
                     f_re = d_re + i_im;
                     f_im = d_im - i_re;
                 end else begin
                     f_re = d_re - i_im;
                     f_im = d_im + i_re;
                 end
            end else begin
                f_re = d_re - i_re;
                f_im = d_im - i_im;
            end
        end else begin
            f_re = i_re;
            f_im = i_im;
        end
    end

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (bottom_edge) begin
                if (swap) begin
                    if (INVERSE) begin
                        o_re <= d_re - i_im;
                        o_im <= d_im + i_re;
                    end else begin
                        o_re <= d_re + i_im;
                        o_im <= d_im - i_re;
                    end
                end else begin
                    o_re <= d_re + i_re;
                    o_im <= d_im + i_im;
                end
            end else begin
                o_re <= d_re;
                o_im <= d_im;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (i_ce) begin
            o_idx <= i_idx - IDX_WIDTH'(STRIDE);
        end
    end

    zerochan_lib_fft_delay
        #(STRIDE, DATA_WIDTH+1)
    u_delay
        (clk, i_ce, f_re, f_im, d_re, d_im);

endmodule : zerochan_lib_fft_bf2

module zerochan_lib_fft_delay #
( parameter int DELAY = 1
, parameter int DATA_WIDTH = 16
)
( input  logic                  clk
, input  logic                  i_ce

, input  logic [DATA_WIDTH-1:0] i_re
, input  logic [DATA_WIDTH-1:0] i_im

, output logic [DATA_WIDTH-1:0] o_re
, output logic [DATA_WIDTH-1:0] o_im
);

    localparam int WORD_WIDTH = DATA_WIDTH * 2;

    generate
    if (DELAY >= 32) begin
        localparam int ADDR_WIDTH = $clog2(DELAY);
        localparam logic [ADDR_WIDTH-1:0] TOP_ADDR = DELAY - 2;

        logic [WORD_WIDTH-1:0] mem [DELAY];
        logic [ADDR_WIDTH-1:0] addr;

        always_ff @(posedge clk) begin
            if (i_ce) begin
                mem[addr] <= {i_re, i_im};
                {o_re, o_im} <= mem[addr];

                if (addr == TOP_ADDR) begin
                    addr <= 0;
                end else begin
                    addr <= addr + ADDR_WIDTH'(1);
                end
            end
        end
    end else if (DELAY >= 4) begin
        localparam int SHR_LEN = DELAY - 1;
        logic [WORD_WIDTH-1:0] shr [SHR_LEN];

        always_ff @(posedge clk) begin
            if (i_ce) begin
                shr <= {shr[1:SHR_LEN-1], {i_re, i_im}};
                {o_re, o_im} <= shr[0];
            end
        end
    end else if (DELAY == 2) begin
        logic [WORD_WIDTH-1:0] stage;

        always_ff @(posedge clk) begin
            if (i_ce) begin
                stage <= {i_re, i_im};
                {o_re, o_im} <= stage;
            end
        end
    end else if (DELAY == 1) begin
        always_ff @(posedge clk) begin
            if (i_ce) begin
                {o_re, o_im} <= {i_re, i_im};
            end
        end
    end else begin
        $fatal("Invalid delay length: %d", DELAY);
    end
    endgenerate

endmodule : zerochan_lib_fft_delay

module zerochan_lib_fft_rom #
( parameter int FFT_N  = 16
, parameter int DEPTH  = 0
, parameter int TWIDDLE_WIDTH  = 16
, parameter bit INVERSE = 0

, parameter int ADDR_WIDTH = (DEPTH + 1) * 2
)
( input  logic                     clk

, input  logic                     i_ce
, input  logic [   ADDR_WIDTH-1:0] i_addr

, output logic [TWIDDLE_WIDTH-1:0] o_re
, output logic [TWIDDLE_WIDTH-1:0] o_im
);

    localparam int A = 4 ** DEPTH;
    localparam int D = 4 ** (DEPTH + 1);

    logic [TWIDDLE_WIDTH*2-1:0] rom [1 << ADDR_WIDTH];

    always_ff @(posedge clk) begin
        if (i_ce) begin
            {o_re, o_im} <= rom[i_addr];
        end
    end

    initial begin : init_rom
        int c, x;

        for (c = 0; c < 4; c++) begin
            var automatic real theta;
            var automatic int s, l, k, cos, sin;

            s = {c[0], c[1]} * (FFT_N / (4 ** (DEPTH + 1)));
            l = c * A;

            for (x = c * A; x < c * A + A; x++) begin
                k = s * (x - l);
                theta = $atan(1.0) * 8 * (real'(k) / real'(FFT_N));

                cos = scale($cos(INVERSE ? theta : -theta));
                sin = scale($sin(INVERSE ? theta : -theta));

                rom[x] = {
                    cos[TWIDDLE_WIDTH-1:0],
                    sin[TWIDDLE_WIDTH-1:0]
                };
            end
        end
    end

    function automatic signed [TWIDDLE_WIDTH-1:0] scale(real x);
        localparam int MAX = ((1 << TWIDDLE_WIDTH - 1) - 1);
        localparam int MIN = (0 - (1 << TWIDDLE_WIDTH - 1));

        var automatic real scaled = x * (1 << TWIDDLE_WIDTH - 1) * $cos($atan(1.0));
        var automatic int v = $rtoi(scaled >= 0.0 ? scaled + 0.5 : scaled - 0.5);

        if (v > MAX) v = MAX;
        if (v < MIN) v = MIN;

        return v;
    endfunction

endmodule : zerochan_lib_fft_rom
