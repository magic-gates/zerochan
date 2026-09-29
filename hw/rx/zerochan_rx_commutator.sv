module zerochan_rx_commutator #
( parameter int FFT_N = 1024
, parameter int INPUT_WIDTH = 22
, parameter int OUTPUT_WIDTH = 18

, parameter int PILOT_SPACING = 16
, parameter int PILOT_OFFSET = 8

, parameter int INDEX_WIDTH = $clog2(FFT_N)
, parameter int PILOTS = FFT_N / PILOT_SPACING
, parameter int PILOTS_WIDTH = $clog2(PILOTS)
, parameter int OFFSET_WIDTH = $clog2(PILOT_SPACING)
)
( input  logic                      clk

, input  logic                      i_ce
, input  logic [   INDEX_WIDTH-1:0] i_idx

, input  logic [   INPUT_WIDTH-1:0] i_re
, input  logic [   INPUT_WIDTH-1:0] i_im

, output logic [   INDEX_WIDTH-1:0] o_idx
, output logic [  OUTPUT_WIDTH-1:0] o_re
, output logic [  OUTPUT_WIDTH-1:0] o_im

, output logic [OUTPUT_WIDTH*2-1:0] o_est [4]
);

    logic [OUTPUT_WIDTH-1:0] re_1, im_1;
    logic [INDEX_WIDTH-1:0] idx_1, fwd_idx_1;

    zerochan_lib_sat_1 #(INPUT_WIDTH, OUTPUT_WIDTH) u_sat_re (clk, i_ce, i_re, re_1);
    zerochan_lib_sat_1 #(INPUT_WIDTH, OUTPUT_WIDTH) u_sat_im (clk, i_ce, i_im, im_1);

    always_ff @(posedge clk) begin
        if (i_ce) begin
            for (int i = 0; i < INDEX_WIDTH; i++) begin
                fwd_idx_1[i] <= i_idx[INDEX_WIDTH-1-i];
            end

            idx_1 <= i_idx;
        end
    end

    logic [INDEX_WIDTH-1:0] fwd_idx_2, idx_2;
    logic signed [OUTPUT_WIDTH-1:0] re_2, im_2;

    logic wr_pilot;
    logic [PILOTS_WIDTH-1:0] pilot_idx;
    logic [PILOTS_WIDTH-1:0] pilot_n1, pilot_n0, pilot_p1, pilot_p2;

    wire [PILOTS_WIDTH-1:0] pilot_base = idx_1[INDEX_WIDTH-1-:PILOTS_WIDTH];

    always_ff @(posedge clk) begin
        if (i_ce) begin
            wr_pilot <= fwd_idx_1[OFFSET_WIDTH-1:0] == OFFSET_WIDTH'(PILOT_OFFSET);
            pilot_idx <= fwd_idx_1[INDEX_WIDTH-1-:PILOTS_WIDTH];

            if (idx_1[OFFSET_WIDTH-1:0] == OFFSET_WIDTH'(PILOT_OFFSET)) begin
                pilot_n1 <= pilot_base - PILOTS_WIDTH'(1);
                pilot_n0 <= pilot_base;
                pilot_p1 <= pilot_base + PILOTS_WIDTH'(1);
                pilot_p2 <= pilot_base + PILOTS_WIDTH'(2);
            end

            idx_2 <= idx_1;
            fwd_idx_2 <= fwd_idx_1;

            {re_2, im_2} <= {re_1, im_1};
        end
    end

    logic [1:0] pilot_rom [PILOTS];

    initial $readmemb("pilots.mem", pilot_rom);

    logic signed [OUTPUT_WIDTH-1:0] ls_re_2, ls_im_2;

    always_comb begin
        unique case (pilot_rom[pilot_idx])
            2'b00: begin
                ls_re_2 = re_2;
                ls_im_2 = im_2;
            end
            2'b01: begin
                ls_re_2 =  im_2;
                ls_im_2 = -re_2;
            end
            2'b10: begin
                ls_re_2 = -re_2;
                ls_im_2 = -im_2;
            end
            2'b11: begin
                ls_re_2 = -im_2;
                ls_im_2 =  re_2;
            end
            default: begin
                ls_re_2 = re_2;
                ls_im_2 = im_2;
            end
        endcase
    end

    logic flip;

    logic [OUTPUT_WIDTH*2-1:0] data_a [FFT_N];
    logic [OUTPUT_WIDTH*2-1:0] data_b [FFT_N];

    logic [OUTPUT_WIDTH*2-1:0] pilots_a [PILOTS];
    logic [OUTPUT_WIDTH*2-1:0] pilots_b [PILOTS];

    logic [INDEX_WIDTH-1:0] idx_3;

    logic [OUTPUT_WIDTH-1:0] z_re, z_im;

    always_ff @(posedge clk) begin
        if (i_ce) begin
            if (idx_2 == INDEX_WIDTH'(FFT_N - 1)) begin
                flip <= ~flip;
            end

            if (flip) begin
                data_b[fwd_idx_2] <= {re_2, im_2};
                {o_re, o_im} <= data_a[idx_2];
            end else begin
                data_a[fwd_idx_2] <= {re_2, im_2};
                {o_re, o_im} <= data_b[idx_2];
            end

            if (wr_pilot) begin
                if (flip) begin
                    pilots_b[pilot_idx] <= {ls_re_2, ls_im_2};
                end else begin
                    pilots_a[pilot_idx] <= {ls_re_2, ls_im_2};
                end
            end

            if (flip) begin
                o_est[0] <= pilots_a[pilot_n1];
                o_est[1] <= pilots_a[pilot_n0];
                o_est[2] <= pilots_a[pilot_p1];
                o_est[3] <= pilots_a[pilot_p2];
            end else begin
                o_est[0] <= pilots_b[pilot_n1];
                o_est[1] <= pilots_b[pilot_n0];
                o_est[2] <= pilots_b[pilot_p1];
                o_est[3] <= pilots_b[pilot_p2];
            end

            o_idx <= idx_2;
        end
    end

endmodule : zerochan_rx_commutator
