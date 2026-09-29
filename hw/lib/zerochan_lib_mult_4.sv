module zerochan_lib_mult_4 #
( parameter int A_WIDTH = 16
, parameter int B_WIDTH = 16
, parameter int ROUND = 0
, parameter bit CONJ = 0

, parameter int OUTPUT_WIDTH = (A_WIDTH+B_WIDTH+1) - ROUND
)
( input  logic                           clk
, input  logic                           ce

, input  logic signed [     A_WIDTH-1:0] a_re
, input  logic signed [     A_WIDTH-1:0] a_im

, input  logic signed [     B_WIDTH-1:0] b_re
, input  logic signed [     B_WIDTH-1:0] b_im

, output logic signed [OUTPUT_WIDTH-1:0] o_re
, output logic signed [OUTPUT_WIDTH-1:0] o_im
);

    logic signed [A_WIDTH:0] s1;
    logic signed [B_WIDTH:0] s2;
    logic signed [A_WIDTH:0] s3;

    logic signed [B_WIDTH-1:0] b_re_1, b_im_1;
    logic signed [A_WIDTH-1:0] a_im_1;

    always_ff @(posedge clk) begin
        if (ce) begin
            s1 <= a_re - a_im;
            s2 <= CONJ ? b_re + b_im : b_re - b_im;
            s3 <= a_re + a_im;

            b_re_1 <= b_re;
            b_im_1 <= CONJ ? -b_im : b_im;
            a_im_1 <= a_im;
        end
    end

    logic signed [A_WIDTH+B_WIDTH:0] p1, p2, p3;

    always_ff @(posedge clk) begin
        if (ce) begin
            p1 <= s1 * b_re_1;
            p2 <= s2 * a_im_1;
            p3 <= s3 * b_im_1;
        end
    end

    logic signed [A_WIDTH+B_WIDTH+1:0] r_re, r_im;

    always_ff @(posedge clk) begin
        if (ce) begin
            r_re <= p1 + p2;
            r_im <= p2 + p3;
        end
    end

    zerochan_lib_round_1
        #(A_WIDTH + B_WIDTH + 2, ROUND)
    u_round_re
        (clk, ce, r_re, o_re);

    zerochan_lib_round_1
        #(A_WIDTH + B_WIDTH + 2, ROUND)
    u_round_im
        (clk, ce, r_im, o_im);

endmodule : zerochan_lib_mult_4
