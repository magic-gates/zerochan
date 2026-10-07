// Complex multiply
module zerochan_cmult #
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

    logic signed [A+B:0] p1, p2, p3;

    always_ff @(posedge clk) begin
        if (ce) begin
            p1 <= s1 * b_re_1;
            p2 <= s2 * a_im_1;
            p3 <= s3 * b_im_1;
        end
    end

    logic signed [A+B+1:0] r_re, r_im;

    always_ff @(posedge clk) begin
        if (ce) begin
            r_re <= p1 + p2;
            r_im <= p2 + p3;
        end
    end

    zerochan_round
        #(A + B + 2, R)
    u_round_re
        (clk, ce, r_re, o_re);

    zerochan_round
        #(A + B + 2, R)
    u_round_im
        (clk, ce, r_im, o_im);

endmodule : zerochan_cmult

// Convergent rounding
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

    wire lsb    =  i[R];
    wire guard  =  i[R-1];

    logic sticky;

    generate
        if (R > 1) begin : gen_sticky
            assign sticky = |i[R-2:0];
        end else begin : gen_no_sticky
            assign sticky = 1'b0;
        end
    endgenerate

    wire round_up = guard & (sticky | lsb);

    wire signed [O:0] sum = $signed(i[I-1:R]) + $signed({1'b0, round_up});
    wire overflow = sum[O] ^ sum[O-1];

    always_ff @(posedge clk) begin
        if (ce) begin
            o <= $signed(overflow ? {1'b0, {(O-1){1'b1}}} : sum[O-1:0]);
        end
    end

endmodule : zerochan_round
