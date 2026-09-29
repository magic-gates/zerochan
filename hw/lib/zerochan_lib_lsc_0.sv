module zerochan_lib_lsc_0 #
( parameter int DATA_WIDTH = 16
, parameter int COUNT_WIDTH = $clog2(DATA_WIDTH)
)
( input  logic [ DATA_WIDTH-1:0] data
, output logic [COUNT_WIDTH-1:0] count
);

    always_comb begin
        count = DATA_WIDTH - 1;

        for (int i = DATA_WIDTH - 2; i >= 0; i--) begin
            if (data[DATA_WIDTH-1] ^ data[i]) begin
                count = DATA_WIDTH - 2 - i;
                break;
            end
        end
    end

endmodule : zerochan_lib_lsc_0
