module zerochan_mult #
( parameter int A = 16
, parameter int B = 16
, parameter int R = 8
, parameter bit C = 0

, parameter int O = (A + B + 1) - R
)
( input  logic                clk
, input  logic                ce

, input  logic signed [A-1:0] a_re
, input  logic signed [A-1:0] a_im

, input  logic signed [B-1:0] b_re
, input  logic signed [B-1:0] b_im

, output logic signed [O-1:0] o_re
, output logic signed [O-1:0] o_im
);

    logic signed [A:0] s1;
    logic signed [B:0] s2;
    logic signed [A:0] s3;

    logic signed [B-1:0] b_re_1, b_im_1;
    logic signed [A-1:0] a_im_1;

    logic signed [A+B:0] p1, p2, p3;

    logic signed [A+B+1:0] r_re, r_im;

    always_ff @(posedge clk) begin
        if (ce) begin
            s1 <= a_re - a_im;
            s2 <= C ? b_re + b_im : b_re - b_im;
            s3 <= a_re + a_im;

            b_re_1 <= b_re;
            b_im_1 <= C ? -b_im : b_im;
            a_im_1 <= a_im;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            p1 <= s1 * b_re_1;
            p2 <= s2 * a_im_1;
            p3 <= s3 * b_im_1;
        end
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            r_re <= p1 + p2;
            r_im <= p2 + p3;
        end
    end

    generate
        if (R > 0) begin : gen_round
            zerochan_round
                #(A + B + 2, R)
            u_round_re
                (clk, ce, r_re, o_re);

            zerochan_round
                #(A + B + 2, R)
            u_round_im
                (clk, ce, r_im, o_im);
        end else begin : gen_direct
            assign o_re = r_re[O-1:0];
            assign o_im = r_im[O-1:0];
        end
    endgenerate

endmodule : zerochan_mult

module zerochan_round #
( parameter int I = 16
, parameter int R = 8
, parameter int O = I - R
)
( input  logic                clk
, input  logic                ce

, input  logic signed [I-1:0] i
, output logic signed [O-1:0] o
);

    generate
        if (R <= 0 || R >= I) begin : gen_validate
            $error("Invalid parameters: ROUND (%0d) must be > 0 and < INPUT (%0d)", R, I);
        end
    endgenerate

    logic lsb, guard;
    logic sticky;

    logic signed [O:0] sum;
    logic round_up, overflow;

    assign lsb = i[R];
    assign guard = i[R-1];

    assign sum = $signed(i[I-1:R]) + $signed({1'b0, round_up});
    assign round_up = guard & (sticky | lsb);
    assign overflow = sum[O] ^ sum[O-1];

    generate
        if (R > 1) begin : gen_sticky
            assign sticky = |i[R-2:0];
        end else begin : gen_no_sticky
            assign sticky = 1'b0;
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (ce) begin
            o <= $signed(overflow ? {1'b0, {(O-1){1'b1}}} : sum[O-1:0]);
        end
    end

endmodule : zerochan_round

module zerochan_sat #
( parameter int W = 32
, parameter int K = 16
)
( input  logic                clk
, input  logic                ce

, input  logic signed [W-1:0] i
, output logic signed [K-1:0] o
);

    localparam logic signed [K-1:0] POS_SAT = {1'b0, {(K-1){1'b1}}};
    localparam logic signed [K-1:0] NEG_SAT = {1'b1, {(K-1){1'b0}}};

    always_ff @(posedge clk) begin
        if (ce) begin
            if (i < NEG_SAT) begin
                o <= NEG_SAT;
            end else if (i > POS_SAT) begin
                o <= POS_SAT;
            end else begin
                o <= i[K-1:0];
            end
        end
    end

endmodule : zerochan_sat

// module zerochan_mult #
// ( parameter int A = 16
// , parameter int B = 16
// , parameter int R = 8
// , parameter bit C = 0
//
// , parameter int O = (A + B + 1) - R
// )
// ( input  logic                clk
// , input  logic                rst
//
// , input  logic                s_valid
// , output logic                s_ready
//
// , input  logic signed [A-1:0] s_a_re
// , input  logic signed [A-1:0] s_a_im
//
// , input  logic signed [B-1:0] s_b_re
// , input  logic signed [B-1:0] s_b_im
//
// , output logic                m_valid
// , input  logic                m_ready
// , output logic signed [O-1:0] m_re
// , output logic signed [O-1:0] m_im
// );
//
//     logic signed [A:0] s1;
//     logic signed [B:0] s2;
//     logic signed [A:0] s3;
//
//     logic signed [B-1:0] b_re_1, b_im_1;
//     logic signed [A-1:0] a_im_1;
//
//     logic signed [A+B:0] p1, p2, p3;
//
//     logic signed [A+B+1:0] r_re, r_im;
//
//     logic ready_1, valid_1;
//     logic ready_2, valid_2;
//     logic ready_3, valid_3;
//     logic ready_4, valid_4;
//
//     assign ready_1 = !valid_1 || ready_2;
//     assign ready_2 = !valid_2 || ready_3;
//     assign ready_3 = !valid_3 || ready_4;
//     assign ready_4 = !valid_4 || m_ready;
//
//     assign s_ready = ready_1;
//
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             valid_1 <= 0;
//         end else if (ready_1) begin
//             valid_1 <= s_valid;
//
//             s1 <= s_a_re - s_a_im;
//             s2 <= C ? s_b_re + s_b_im : s_b_re - s_b_im;
//             s3 <= s_a_re + s_a_im;
//
//             b_re_1 <= s_b_re;
//             b_im_1 <= C ? -s_b_im : s_b_im;
//             a_im_1 <= s_a_im;
//         end
//     end
//
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             valid_2 <= 0;
//         end else if (ready_2) begin
//             valid_2 <= valid_1;
//
//             p1 <= s1 * b_re_1;
//             p2 <= s2 * a_im_1;
//             p3 <= s3 * b_im_1;
//         end
//     end
//
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             valid_3 <= 0;
//         end else if (ready_3) begin
//             valid_3 <= valid_2;
//
//             r_re <= p1 + p2;
//             r_im <= p2 + p3;
//         end
//     end
//
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             valid_4 <= 0;
//         end else if (ready_4) begin
//             valid_4 <= valid_3;
//         end
//     end
//
//     zerochan_round
//         #(A + B + 2, R)
//     u_round_re
//         (clk, ready_4, r_re, m_re);
//
//     zerochan_round
//         #(A + B + 2, R)
//     u_round_im
//         (clk, ready_4, r_im, m_im);
//
// endmodule : zerochan_mult
//
// module zerochan_round #
// ( parameter int I = 16
// , parameter int R = 8
// , parameter int O = I - R
// )
// ( input  logic                clk
// , input  logic                ce
//
// , input  logic signed [I-1:0] i
// , output logic signed [O-1:0] o
// );
//
//     generate
//         if (R <= 0 || R >= I) begin : gen_validate
//             $error("Invalid parameters: ROUND (%0d) must be > 0 and < INPUT (%0d)", R, I);
//         end
//     endgenerate
//
//     logic lsb, guard;
//     logic sticky;
//
//     logic signed [O:0] sum;
//     logic round_up, overflow;
//
//     assign lsb = i[R];
//     assign guard = i[R-1];
//
//     assign sum = $signed(i[I-1:R]) + $signed({1'b0, round_up});
//     assign round_up = guard & (sticky | lsb);
//     assign overflow = sum[O] ^ sum[O-1];
//
//     generate
//         if (R > 1) begin : gen_sticky
//             assign sticky = |i[R-2:0];
//         end else begin : gen_no_sticky
//             assign sticky = 1'b0;
//         end
//     endgenerate
//
//     always_ff @(posedge clk) begin
//         if (ce) begin
//             o <= $signed(overflow ? {1'b0, {(O-1){1'b1}}} : sum[O-1:0]);
//         end
//     end
//
// endmodule : zerochan_round
