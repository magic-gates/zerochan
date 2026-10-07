module zerochan_delay #
( parameter int DW = 12
, parameter int LEN = 32
)
( input  logic          clk
, input  logic          ce

, input  logic [DW-1:0] i
, output logic [DW-1:0] o
);

    localparam int AW = $clog2(LEN);

    logic [DW-1:0] line [LEN];
    logic [AW-1:0] addr;

    always_ff @(posedge clk) begin
        if (ce) begin
            line[addr] <= i;
            o <= line[addr];
            addr <= AW'(addr + 'd1);
        end
    end

endmodule : zerochan_delay
