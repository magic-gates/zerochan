module zerochan_retimer #
( parameter int unsigned LEN = 1024
, parameter int DW = 12
, parameter int ID = $clog2(LEN)
)
( input  logic                 clk
, input  logic                 rst
, input  logic                 ce

, input  logic                 i_err_valid
, input  logic signed [ID-1:0] i_err

, input  logic signed [DW-1:0] i_re
, input  logic signed [DW-1:0] i_im

, output logic                 o_valid
, output logic        [ID-1:0] o_id
, output logic signed [DW-1:0] o_re
, output logic signed [DW-1:0] o_im
);

    localparam int AW = $clog2(LEN*2);

    logic [ID-1:0] id;

    logic [DW*2-1:0] mem [LEN*2];
    logic [AW-1:0] wa, ra;
    logic [AW-1:0] fill;

    assign fill = wa - ra;

    always_ff @(posedge clk) begin
        if (ce) begin
            mem[wa] <= {i_re, i_im};
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wa <= 0;
        end else if (ce) begin
            wa <= AW'(wa + 'd1);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            ra <= 0;
            id <= 0;
        end else if (ce) begin
            if (fill >= AW'(LEN)) begin
                o_valid <= 1'b1;
                id <= id + 'd1;
                {o_re, o_im} <= mem[ra];
                o_id <= id;
                ra <= AW'(ra + 'd1);
            end else begin
                o_valid <= 1'b0;
            end
        end
    end

endmodule : zerochan_retimer
