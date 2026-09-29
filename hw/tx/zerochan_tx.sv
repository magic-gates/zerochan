module zerochan_tx
( input  logic               clk

, input  logic               i_valid
, output logic               o_ready
, output logic        [ 9:0] o_idx

, input  logic signed [ 9:0] i_re
, input  logic signed [ 9:0] i_im

, output logic signed [11:0] o_re
, output logic signed [11:0] o_im
);

    logic valid, active, pilot;
    logic [9:0] p_re, p_im;
    logic [9:0] idx;

    logic [9:0] f_idx;
    logic [9:0] f_re, f_im;

    logic [9:0] t_idx;
    logic [19:0] t_re, t_im;

    logic ce;

    assign o_idx = idx;

    always_ff @(posedge clk) begin
        if (valid) begin
            if (active) begin
                if (pilot) begin
                    {f_re, f_im} <= {p_re, p_im};
                end else if (i_valid) begin
                    {f_re, f_im} <= {i_re, i_im};
                end else begin
                    {f_re, f_im} <= {10'd0, 10'd0};
                end
            end else begin
                {f_re, f_im} <= {10'd0, 10'd0};
            end

            ce <= 1'b1;
            o_ready <= active & ~pilot;
        end else begin
            ce <= 1'b0;
            o_ready <= 1'b0;
        end

        f_idx <= idx;
    end

    zerochan_tx_source #
    ( .FFT_N(1024)
    , .CP(61)
    , .DATA_P(/*488*/488)
    , .DATA_N(/*536*/536)
    , .PILOT_WIDTH(10)
    , .PILOT_SPACING(16)
    , .PILOT_OFFSET(8)
    ) u_src
    ( .clk(clk)

    , .o_idx(idx)

    , .o_valid(valid)
    , .o_active(active)
    , .o_pilot(pilot)

    , .o_p_re(p_re)
    , .o_p_im(p_im)
    );

    zerochan_lib_fft_1024 #
    ( .INPUT_WIDTH(10)
    , .TWIDDLE_WIDTH(18)
    , .INVERSE(1'b1)
    ) u_ifft
    ( .clk(clk)

    , .i_ce(ce)

    , .i_idx(f_idx)
    , .i_re(f_re)
    , .i_im(f_im)

    , .o_idx(t_idx)
    , .o_re(t_re)
    , .o_im(t_im)
    );

    zerochan_tx_gearbox #
    ( .FFT_N(1024)
    , .CP(61)
    , .INPUT_WIDTH(20)
    , .OUTPUT_WIDTH(12)
    ) u_gearbox
    ( .clk(clk)

    , .i_ce(ce)
    , .i_idx(t_idx)
    , .i_re(t_re)
    , .i_im(t_im)

    , .o_re(o_re)
    , .o_im(o_im)
    );

endmodule : zerochan_tx

module zerochan_tx_source #
( parameter int FFT_N = 1024
, parameter int CP = 64
, parameter int DATA_P = 512
, parameter int DATA_N = 512
, parameter int PILOT_WIDTH = 16
, parameter int PILOT_SPACING = 16
, parameter int PILOT_OFFSET = 8

, parameter int TOTAL = FFT_N + CP
, parameter int COUNTER_WIDTH = $clog2(TOTAL)
, parameter int INDEX_WIDTH = COUNTER_WIDTH - 1
)
( input  logic                   clk

, output logic [INDEX_WIDTH-1:0] o_idx

, output logic                   o_valid
, output logic                   o_active
, output logic                   o_pilot

, output logic [PILOT_WIDTH-1:0] o_p_re
, output logic [PILOT_WIDTH-1:0] o_p_im
);

    localparam int PILOTS = FFT_N / PILOT_SPACING;
    localparam int PILOTS_WIDTH = $clog2(PILOTS);
    localparam int PILOT_OFFSET_WIDTH = $clog2(PILOT_OFFSET) + 1;

    localparam logic [PILOT_WIDTH-1:0] PILOT_P = {1'b0, {(PILOT_WIDTH-1){1'b1}}};
    localparam logic [PILOT_WIDTH-1:0] PILOT_N = {1'b1, {(PILOT_WIDTH-2){1'b0}}, 1'b1};

    logic [COUNTER_WIDTH-1:0] counter;
    wire [INDEX_WIDTH-1:0] idx = counter[INDEX_WIDTH-1:0];

    always_ff @(posedge clk) begin
        if (counter == COUNTER_WIDTH'(TOTAL - 1)) begin
            counter <= 0;
        end else begin
            counter <= counter + COUNTER_WIDTH'(1);
        end
    end

    logic is_active, is_pilot;
    logic [PILOTS_WIDTH-1:0] pilot_idx;

    logic [COUNTER_WIDTH-1:0] counter_1;
    wire [INDEX_WIDTH-1:0] idx_1 = counter_1[INDEX_WIDTH-1:0];

    always_ff @(posedge clk) begin
        is_active <= idx != 0 && (idx <= INDEX_WIDTH'(DATA_P) || idx >= INDEX_WIDTH'(DATA_N));
        is_pilot <= idx[PILOT_OFFSET_WIDTH-1:0] == PILOT_OFFSET_WIDTH'(PILOT_OFFSET);
        pilot_idx <= idx[INDEX_WIDTH-1-:PILOTS_WIDTH];

        counter_1 <= counter;
    end

    logic [1:0] pilot_rom [PILOTS];
    initial $readmemb("pilots.mem", pilot_rom);

    always_ff @(posedge clk) begin
        if (~counter_1[COUNTER_WIDTH-1]) begin
            o_valid <= 1'b1;
            o_active <= is_active;
            o_pilot <= is_pilot;
            o_idx <= idx_1;

            unique case (pilot_rom[pilot_idx])
                2'b00: {o_p_re, o_p_im} <= {PILOT_P, PILOT_WIDTH'(0)};
                2'b01: {o_p_re, o_p_im} <= {PILOT_WIDTH'(0), PILOT_P};
                2'b10: {o_p_re, o_p_im} <= {PILOT_N, PILOT_WIDTH'(0)};
                2'b11: {o_p_re, o_p_im} <= {PILOT_WIDTH'(0), PILOT_N};
            endcase
        end else begin
            o_valid <= 1'b0;
        end
    end

endmodule : zerochan_tx_source

module zerochan_tx_gearbox #
( parameter int FFT_N = 1024
, parameter int CP = 64
, parameter int INPUT_WIDTH = 20
, parameter int OUTPUT_WIDTH = 10

, parameter int INDEX_WIDTH = $clog2(FFT_N)
)
( input  logic                           clk

, input  logic                           i_ce
, input  logic        [ INDEX_WIDTH-1:0] i_idx
, input  logic signed [ INPUT_WIDTH-1:0] i_re
, input  logic signed [ INPUT_WIDTH-1:0] i_im

, output logic signed [OUTPUT_WIDTH-1:0] o_re
, output logic signed [OUTPUT_WIDTH-1:0] o_im
);

    localparam int LSC = $clog2(INPUT_WIDTH);

    logic [LSC-1:0] lsc_re, lsc_im;

    zerochan_lib_lsc_0 #(INPUT_WIDTH) u_lsc_re (i_re, lsc_re);
    zerochan_lib_lsc_0 #(INPUT_WIDTH) u_lsc_im (i_im, lsc_im);

    logic [LSC-1:0] lsc_top;
    logic [INPUT_WIDTH-1:0] re_1, im_1;
    logic [INDEX_WIDTH-1:0] idx_1;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            lsc_top <= lsc_re <= lsc_im ? lsc_re : lsc_im;
            {re_1, im_1} <= {i_re, i_im};
            idx_1 <= i_idx;
        end
    end

    logic [LSC-1:0] lsc_min;
    logic [INDEX_WIDTH-1:0] idx_2;
    logic [INPUT_WIDTH-1:0] re_2, im_2;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (idx_1 == 0) begin
                lsc_min <= LSC'(INPUT_WIDTH - 1);
            end else if (lsc_top < lsc_min) begin
                lsc_min <= lsc_top;
            end

            {re_2, im_2} <= {re_1, im_1};
            idx_2 <= idx_1;
        end
    end

    logic [INPUT_WIDTH-1:0] re_3, im_3;
    logic [INDEX_WIDTH-1:0] fwd_idx, rev_idx;
    logic [LSC-1:0] gain;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (idx_2 == INDEX_WIDTH'(FFT_N - 1)) begin
                gain <= lsc_min;
            end

            {re_3, im_3} <= {re_2, im_2};
            fwd_idx <= idx_2;

            for (int i = 0; i < INDEX_WIDTH; i++) begin
                rev_idx[i] <= idx_2[INDEX_WIDTH-1-i];
            end
        end
    end

    localparam int ADDR_WIDTH = $clog2(FFT_N);
    localparam int WORD_WIDTH = INPUT_WIDTH * 2;

    logic flip;

    logic [WORD_WIDTH-1:0] a_ram [FFT_N];
    logic [WORD_WIDTH-1:0] b_ram [FFT_N];

    logic [INDEX_WIDTH-1:0] ptr;

    logic [LSC-1:0] gain_1;

    always_ff @(posedge clk) begin
        ptr <= ptr + INDEX_WIDTH'(1);

        if (i_ce) begin
            if (fwd_idx == INDEX_WIDTH'(FFT_N - 1)) begin
                flip <= ~flip;
                ptr <= INDEX_WIDTH'(FFT_N - CP);
            end

            if (flip) begin
                b_ram[rev_idx] <= {re_3, im_3};
            end else begin
                a_ram[rev_idx] <= {re_3, im_3};
            end

            gain_1 <= gain;
        end
    end

    logic [LSC-1:0] gain_2;
    logic [INPUT_WIDTH-1:0] z_re, z_im;

    always_ff @(posedge clk) begin
        {z_re, z_im} <= flip ? a_ram[ptr] : b_ram[ptr];
        gain_2 <= gain_1;
    end

    logic [INPUT_WIDTH-1:0] amp_re, amp_im;

    always_ff @(posedge clk) begin
        amp_re <= z_re << gain_2;
        amp_im <= z_im << gain_2;
    end

    zerochan_lib_round_1 #(INPUT_WIDTH, INPUT_WIDTH-OUTPUT_WIDTH) u_round_re
        (clk, 1'b1, amp_re, o_re);

    zerochan_lib_round_1 #(INPUT_WIDTH, INPUT_WIDTH-OUTPUT_WIDTH) u_round_im
        (clk, 1'b1, amp_im, o_im);

endmodule : zerochan_tx_gearbox
