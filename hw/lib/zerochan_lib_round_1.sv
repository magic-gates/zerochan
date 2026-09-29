module zerochan_lib_round_1 #
( parameter int INPUT = 16
, parameter int ROUND = 8
, parameter int OUTPUT = INPUT - ROUND
)
( input  logic                     clk

, input  logic                     ce

, input  logic signed [ INPUT-1:0] i
, output logic signed [OUTPUT-1:0] o
);

    generate
        if (ROUND <= 0 || ROUND >= INPUT) begin : gen_validate
            $error("Invalid parameters: ROUND (%0d) must be > 0 and < INPUT (%0d)", ROUND, INPUT);
        end
    endgenerate

    wire sign   = i[INPUT-1];

    wire lsb    =  i[ROUND];
    wire guard  =  i[ROUND-1];

    logic sticky;

    generate
        if (ROUND > 1) begin : gen_sticky
            assign sticky = |i[ROUND-2:0];
        end else begin : gen_no_sticky
            assign sticky = 1'b0;
        end
    endgenerate

    wire round_up = guard & (sticky | lsb);

    wire [OUTPUT:0] sum = $signed(i[INPUT-1:ROUND]) + $signed({1'b0, round_up});
    wire overflow = sum[OUTPUT] ^ sum[OUTPUT-1];

    always_ff @(posedge clk) begin
        if (ce) begin
            o <= overflow ? {1'b0, {(OUTPUT-1){1'b1}}} : sum[OUTPUT-1:0];
        end
    end

endmodule : zerochan_lib_round_1
