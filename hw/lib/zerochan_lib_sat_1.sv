module zerochan_lib_sat_1 #
( parameter int DATA_WIDTH = 32
, parameter int KEEP_BITS = 16

, parameter int EDGE = "BOTH"
)
( input  logic                         clk
, input  logic                         ce

, input  logic signed [DATA_WIDTH-1:0] i
, output logic signed [ KEEP_BITS-1:0] o
);

    localparam logic signed [KEEP_BITS-1:0] POS_SAT = {1'b0, {(KEEP_BITS-1){1'b1}}};
    localparam logic signed [KEEP_BITS-1:0] NEG_SAT = {1'b1, {(KEEP_BITS-1){1'b0}}};

    generate if (EDGE == "POS") begin
        always_ff @(posedge clk) begin
            if (ce) begin
                if (i > POS_SAT) begin
                    o <= POS_SAT;
                end else begin
                    o <= i[KEEP_BITS-1:0];
                end
            end
        end
    end else begin
        always_ff @(posedge clk) begin
            if (ce) begin
                if (i < NEG_SAT) begin
                    o <= NEG_SAT;
                end else if (i > POS_SAT) begin
                    o <= POS_SAT;
                end else begin
                    o <= i[KEEP_BITS-1:0];
                end
            end
        end
    end endgenerate

endmodule : zerochan_lib_sat_1
