module zerochan_rx #
( parameter int DW = 12
)
( input  logic                 clk
, input  logic                 rst
, input  logic                 ce

, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic signed [DW-1:0] m_re
, input  logic signed [DW-1:0] m_im
);

    logic signed [DW-1:0] ps_re, ps_im;

    zerochan_ps_rx #(DW) u_ps
    ( .clk(clk)
    , .rst(rst)
    , .ce(ce)

    , .i_re(s_re)
    , .i_im(s_im)

    , .o_re(ps_re)
    , .o_im(ps_im)
    );

    zerochan_rx_sync #(DW, 512, 32) u_sync
    ( .clk(clk)
    , .rst(rst)
    , .ce(ce)

    , .i_re(ps_re)
    , .i_im(ps_im)

    , .o_id()
    , .o_re()
    , .o_im()
    );

endmodule : zerochan_rx

module zerochan_rx_sync #
( parameter int DW = 12
, parameter int BLOCK_LEN = 512
, parameter int UW_LEN = 32
, parameter int ID = $clog2(BLOCK_LEN*2)
)
( input  logic                 clk
, input  logic                 rst
, input  logic                 ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic        [ID-1:0] o_id
, input  logic signed [DW-1:0] o_re
, input  logic signed [DW-1:0] o_im
);

    localparam int TM = $clog2(UW_LEN) + 2;
    localparam int DW1 = DW + 1;

    logic [ID-1:0] id;

    always_ff @(posedge clk) begin
        if (rst) begin
            id <= 0;
        end else if (ce) begin
            id <= ID'(id + 'd1);
        end
    end

    logic signed [DW1-1:0] re_1, im_1;
    logic [ID-1:0] id_1;

    zerochan_mixer #
    ( .DW(12)
	, .AW(16)
	, .ID(ID)

	, .LUT_WIDTH(14)
	, .LUT_DEPTH(11)
     ) u_mixer
    ( .clk(clk)
    , .rst(rst)
    , .ce(ce)

	, .i_vel(0)
	, .i_id(id)

	, .i_re(i_re)
	, .i_im(i_im)

	, .o_id(id_1)
	, .o_re(re_1)
	, .o_im(im_1)
    );

    logic [ID-1:0] tm_id;
    logic [DW1-1:0] tm_re, tm_im;

    logic tm_peak_valid;
    logic signed [ID-1:0] tm_peak_offset;
    logic signed [TM-1:0] tm_peak_re, tm_peak_im;

    zerochan_rx_timing #
    ( .DW(DW1)
    , .BL(BLOCK_LEN)
    , .UL(UW_LEN)
    ) u_timing
    ( .clk(clk)
    , .rst(rst)
    , .ce(ce)

    , .i_re(re_1)
    , .i_im(im_1)

    , .o_peak_valid(tm_peak_valid)
    , .o_peak_offset(tm_peak_offset)
    , .o_peak_re(tm_peak_re)
    , .o_peak_im(tm_peak_im)

    , .o_id(tm_id)
    , .o_re(tm_re)
    , .o_im(tm_im)
    );

    logic rt_valid;
    logic [ID-1:0] rt_id;
    logic signed [DW1-1:0] rt_re, rt_im;

    zerochan_retimer #(BLOCK_LEN*2, DW1) u_retimer
    ( .clk(clk)
    , .rst(rst)
    , .ce(ce)

    , .i_re(tm_re)
    , .i_im(tm_im)

    , .i_err_valid()
    , .i_err()

    , .o_valid(rt_valid)
    , .o_id(rt_id)
    , .o_re(rt_re)
    , .o_im(rt_im)
    );

//     zerochan_rx_pse #
//     ( .DW(DW1)
//     , .UW_LEN(UW_LEN)
//     , .UW_INIT("uw.mem")
//     ) u_pse
//     ( .clk(clk)
//     , .rst(rst)
//     , .ce(ce)
//
//     , .i_sync(tm > TM'('d16))
//
//     , .i_re(re_2)
//     , .i_im(im_2)
//     );
//
//     logic rt_valid;
//     logic [ID-1:0] rt_id;
//     logic signed [DW1-1:0] rt_re, rt_im;
//
//     zerochan_retimer #(BLOCK_LEN*2, DW1) u_retimer
//     ( .clk(clk)
//     , .rst(rst)
//     , .ce(ce)
//
//     , .i_re(re_2)
//     , .i_im(im_2)
//
//     , .o_valid(rt_valid)
//     , .o_id(rt_id)
//     , .o_re(rt_re)
//     , .o_im(rt_im)
//     );
//
//     logic strobe;
//     logic signed [DW1-1:0] re_3, im_3;
//     logic [ID-1:0] id_3;
//
//     always_ff @(posedge clk) begin
//         if (ce) begin
//             strobe <= ~strobe;
//
//             if (!strobe) begin
//                 {re_3, im_3} <= {re_2, im_2};
//                 id_3 <= id_2;
//             end
//         end
//     end

endmodule : zerochan_rx_sync

module zerochan_rx_timing #
( parameter int DW = 12
, parameter int BL = 512
, parameter int UL = 32
, parameter int ID = $clog2(BL*2)
, parameter int TM = $clog2(UL) + 2
)
( input  logic                  clk
, input  logic                  rst
, input  logic                  ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic                 o_peak_valid
, output logic signed [ID-1:0] o_peak_offset
, output logic signed [TM-1:0] o_peak_re
, output logic signed [TM-1:0] o_peak_im

, output logic        [ID-1:0] o_id
, output logic signed [DW-1:0] o_re
, output logic signed [DW-1:0] o_im
);

    logic [ID-1:0] t1_id, t2_id;

    logic signed [TM-1:0] rel_re, rel_im;
    logic signed [TM-1:0] abs_re, abs_im;

    zerochan_rx_relative_timing_3
        #(DW, BL, UL)
    u_rel
        (clk, rst, ce, i_re, i_im, rel_re, rel_im);

    zerochan_rx_absolute_timing_3
        #(DW, UL)
    u_abs
        (clk, ce, i_re, i_im, abs_re, abs_im);

    logic [DW-1:0] re_1, im_1;
    logic [DW-1:0] re_2, im_2;
    logic [DW-1:0] re_3, im_3;
    logic [DW-1:0] re_4, im_4;
    logic [DW-1:0] re_5, im_5;

    always_ff @(posedge clk) begin
        if (ce) begin
            {re_1, im_1} <= {i_re, i_im};
            {re_2, im_2} <= {re_1, im_1};
            {re_3, im_3} <= {re_2, im_2};

            {re_4, im_4} <= {re_3, im_3};
            {re_5, im_5} <= {re_4, im_4};
        end
    end

    logic [TM*2-3:0] rel_mag, abs_mag;
    logic signed [TM-1:0] rel_re_1, rel_im_1;

    always_ff @(posedge clk) begin
        if (ce) begin
            rel_mag <= (rel_re * rel_re) + (rel_im * rel_im);
            abs_mag <= (abs_re * abs_re) + (abs_im * abs_im);

            {rel_re_1, rel_im_1} <= {rel_re, rel_im};
        end
    end

    logic [TM*2-3:0] mag;
    logic signed [TM-1:0] rel_re_2, rel_im_2;

    always_ff @(posedge clk) begin
        mag <= rel_mag[TM*2-3-:TM] * abs_mag[TM*2-3-:TM];

        {rel_re_2, rel_im_2} <= {rel_re_1, rel_im_1};
    end

    logic [ID-1:0] id;
    logic signed [ID-1:0] offset_id;

    logic [TM*2-3:0] peak_mag;
    logic signed [ID-1:0] peak_id;
    logic signed [TM-1:0] peak_re, peak_im;

    assign o_peak_valid = offset_id == ID'(BL-1);
    assign o_peak_offset = peak_id;
    assign o_peak_re = peak_re;
    assign o_peak_im = peak_im;

    assign o_id = id;
    assign o_re = re_5;
    assign o_im = im_5;

    always_ff @(posedge clk) begin
        if (rst) begin
            id <= 0;
            // We want the offset relative to frame start,
            // not to the peak itself which is 2 samples before frame
            offset_id <= ID'('sd2);
        end else if (ce) begin
            id <= ID'(id + 'd1);
            offset_id <= ID'(offset_id + 'sd1);

            if (mag > peak_mag || id == offset_id == ID'(BL-1)) begin
                peak_id <= offset_id;
                peak_re <= rel_re_2;
                peak_im <= rel_im_2;
                peak_mag <= mag;
            end
        end
    end

endmodule : zerochan_rx_timing

module zerochan_rx_absolute_timing_3 #
( parameter int DW = 12
, parameter int UL = 32
, parameter int TM = $clog2(UL) + 2

, parameter string UW_INIT = "uw.mem"
)
( input  logic                  clk
, input  logic                  ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic signed [TM-1:0] o_re
, output logic signed [TM-1:0] o_im
);

    logic re_sign, im_sign;

    logic [UL*4-1:0] line;
    logic [UL-1:0] taps_re, taps_im;

    logic [UL-1:0] uw_re, uw_im;

    logic [UL-1:0] rr, ii, ir, ri;
    logic [TM-1:0] u_rr, u_ii, u_ir, u_ri;

    assign re_sign = i_re[DW-1];
    assign im_sign = i_im[DW-1];

    assign rr = taps_re ^ uw_re;
    assign ii = taps_im ^ uw_im;
    assign ir = taps_im ^ uw_re;
    assign ri = taps_re ^ uw_im;

    always_comb begin
        for (int i = 0; i < UL; i++) begin
            taps_re[i] = line[i*4+1];
            taps_im[i] = line[i*4+0];
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            line <= {line[UL*4-3:0], {re_sign, im_sign}};
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            u_rr <= $countones(rr);
            u_ii <= $countones(ii);
            u_ir <= $countones(ir);
            u_ri <= $countones(ri);
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            o_re <= TM'(UL) - u_rr - u_ii;
            o_im <= u_ri - u_ir;
        end
    end

    initial begin
        var logic [1:0] uw [UL];
        $readmemb(UW_INIT, uw);

        for (int i = 0; i < UL; i++) begin
            uw_re[i] = uw[UL-1-i][1];
            uw_im[i] = uw[UL-1-i][0];
        end
    end

endmodule : zerochan_rx_absolute_timing_3

module zerochan_rx_relative_timing_3 #
( parameter int DW = 12
, parameter int BL = 512
, parameter int UL = 32

, parameter int TM = $clog2(UL) + 2
)
( input  logic                  clk
, input  logic                  rst
, input  logic                  ce

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic signed [TM-1:0] o_re
, output logic signed [TM-1:0] o_im
);

    logic [BL*4-1:0] line;

    logic re_sign, im_sign;
    logic rr, ii, ir, ri;

    logic signed [1:0] p_re, p_im;

    logic [UL*8-1:0] window;

    assign re_sign = i_re[DW-1];
    assign im_sign = i_im[DW-1];

    assign rr = re_sign ^ line[1];
    assign ii = im_sign ^ line[0];
    assign ir = im_sign ^ line[1];
    assign ri = re_sign ^ line[0];

    assign p_re = $signed({rr & ii, rr ~^ ii});
    assign p_im = $signed({ir & ~ri, ir ^ ri});

    always_ff @(posedge clk) begin
        if (ce) begin
            line <= {{re_sign, im_sign}, line[BL*4-1:2]};
        end
    end

    logic sel;

    logic signed [TM-1:0] acc_re [2];
    logic signed [TM-1:0] acc_im [2];

    always_ff @(posedge clk) begin
        if (rst) begin
            sel <= 0;

            acc_re <= '{default:0};
            acc_im <= '{default:0};
        end else if (ce) begin
            window <= {{p_re, p_im}, window[UL*8-1:4]};

            acc_re[sel] <= acc_re[sel] - $signed(window[3:2]) + p_re;
            acc_im[sel] <= acc_im[sel] - $signed(window[1:0]) + p_im;

            sel <= ~sel;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            o_re <= acc_re[sel];
            o_im <= acc_im[sel];
        end
    end

endmodule : zerochan_rx_relative_timing_3

module zerochan_rx_pse #
( parameter int unsigned DW = 12
, parameter int unsigned UW_LEN = 32

, parameter string UW_INIT = "uw.mem"
)
( input logic                 clk
, input logic                 rst
, input logic                 ce

, input logic                 i_sync

, input logic signed [DW-1:0] i_re
, input logic signed [DW-1:0] i_im
);

    localparam int AW = $clog2(UW_LEN*2);

    logic [1:0] uw_rom [UW_LEN];

    initial $readmemb(UW_INIT, uw_rom);

    logic run;

    logic [DW*2-1:0] line [UW_LEN*2];
    logic [AW-1:0] addr, cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            run <= 0;
            cnt <= 0;
        end else if (ce) begin
            if (run) begin
                if (cnt == AW'(UW_LEN-1)) begin
                    cnt <= 0;
                    run <= 0;
                end else begin
                    cnt <= AW'(cnt + 'd1);
                    addr <= AW'(addr + 'd2);
                end
            end else begin
                line[addr] <= {i_re, i_im};
                addr <= AW'(addr + 'd1);

                if (i_sync) begin
                    run <= 1'b1;
                end
            end
        end
    end

    logic signed [DW-1:0] re_1, im_1;
    logic [AW-1:0] id_1;
    logic valid_1;

    always_ff @(posedge clk) begin
        if (ce) begin
            valid_1 <= run;
            id_1 <= cnt;
            {re_1, im_1} <= line[addr];
        end
    end

    logic signed [DW:0] re_2, im_2;
    logic [AW-1:0] id_2;
    logic valid_2;

    always_ff @(posedge clk) begin
        if (ce) begin
            unique case (uw_rom[id_1])
                2'b00: begin
                    re_2 <= re_1 + im_1;
                    im_2 <= im_1 - re_1;
                end
                2'b01: begin
                    re_2 <= re_1 - im_1;
                    im_2 <= re_1 + im_1;
                end
                2'b10: begin
                    re_2 <=  im_1 - re_1;
                    im_2 <= -re_1 - im_1;
                end
                2'b11: begin
                    re_2 <= -re_1 - im_1;
                    im_2 <=  re_1 - im_1;
                end
            endcase

            id_2 <= id_1;
            valid_2 <= valid_1;
        end
    end

    logic signed [DW:0] p_re, p_im;
    logic p_valid;

    always_ff @(posedge clk) begin
        if (ce) begin
            p_valid <= valid_2;
            {p_re, p_im} <= {re_2, im_2};
        end
    end

    logic signed [DW:0] diff_re, diff_im;
    logic valid_3, valid_4, valid_5, diff_valid;

    always_ff @(posedge clk) begin
        if (ce) begin
            valid_3 <= p_valid && valid_2;
            valid_4 <= valid_3;
            valid_5 <= valid_4;
            diff_valid <= valid_5;
        end
    end

    zerochan_cmult #
    ( .A(DW+1)
    , .B(DW+1)
    , .R(DW-1)
    , .C(1'b1)
    ) u_mult
    ( .clk(clk)
    , .ce(ce)

    , .a_re(re_2)
    , .a_im(im_2)

    , .b_re(p_re)
    , .b_im(p_im)

    , .o_re(diff_re)
    , .o_im(diff_im)
    );

    // logic [AW-1:0] ring_addr, cnt;
    // logic [AW-1:0] it_addr, prev_addr, mult_addr;

    // logic signed [DW:0] dm_re, dm_im;

    // logic [3:0] mult_valid;
    // logic [AW-1:0] cnt_1, cnt_2, cnt_3, cnt_4;
    // logic signed [DW:0] diff_re, diff_im;

    // enum logic [1:0]
    // { IDLE
    // , DEMOD
    // , DIFF
    // } state;

    // assign it_addr = ring_addr + cnt;
    // assign prev_addr = it_addr - AW'('d2);
    // assign mult_addr = ring_addr + cnt_4;

    // always_comb begin
    //     var logic signed [DW:0] r_re, r_im;

    //     {r_re, r_im} = line[cnt];

    //     unique case (uw_rom[cnt >> 1])
    //         2'b00: begin
    //             dm_re = r_re + r_im;
    //             dm_im = r_im - r_re;
    //         end
    //         2'b01: begin
    //             dm_re = r_re - r_im;
    //             dm_im = r_re + r_im;
    //         end
    //         2'b10: begin
    //             dm_re = -r_re - r_im;
    //             dm_im =  r_re - r_im;
    //         end
    //         2'b11: begin
    //             dm_re =  r_im - r_re;
    //             dm_im = -r_re - r_im;
    //         end
    //     endcase
    // end

    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         ring_addr <= 0;
    //         cnt <= 0;
    //         state <= IDLE;
    //     end else if (ce) unique case (state)
    //         IDLE: begin
    //             line[ring_addr] <= {
    //                 {i_re[DW-1], i_re},
    //                 {i_im[DW-1], i_im}
    //             };

    //             ring_addr <= AW'(ring_addr + 'd1);

    //             if (i_sync) begin
    //                 cnt <= AW'('d1);
    //                 state <= DEMOD;
    //             end
    //         end
    //         DEMOD: begin
    //             line[it_addr] <= {dm_re, dm_im};

    //             if (cnt == AW'(UW_LEN*2-1)) begin
    //                 cnt <= AW'('d3);
    //                 state <= DIFF;
    //             end else begin
    //                 cnt <= AW'(cnt + 'd2);
    //             end
    //         end
    //         DIFF: if (mult_valid[3]) begin
    //             line[mult_addr] <= {diff_re, diff_im};

    //             if (cnt == AW'(UW_LEN*2-1)) begin

    //             end else begin
    //                 cnt <= AW'(cnt + 'd2);
    //             end
    //         end
    //     endcase
    // end

    // always_ff @(posedge clk) begin
    //     if (ce) begin
    //         cnt_1 <= cnt;
    //         cnt_2 <= cnt_1;
    //         cnt_3 <= cnt_2;
    //         cnt_4 <= cnt_3;

    //         mult_valid <= state == DIFF ? {mult_valid[2:0], 1'b1} : 4'b0000;
    //     end
    // end

    // zerochan_cmult #
    // ( .A(DW+1)
    // , .B(DW+1)
    // , .R(DW-1)
    // , .C(1'b1)
    // ) u_mult
    // ( .clk(clk)
    // , .ce(state == DIFF)

    // , .a_re(line[it_addr][DW*2-:DW])
    // , .a_im(line[it_addr][DW:0])

    // , .b_re(line[prev_addr][DW*2-:DW])
    // , .b_im(line[prev_addr][DW:0])

    // , .o_re(diff_re)
    // , .o_im(diff_im)
    // );

endmodule : zerochan_rx_pse
