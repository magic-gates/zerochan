module zerochan_fifo #
( parameter int unsigned DEPTH = 8
, parameter int W = 8

, parameter int A = $clog2(DEPTH)
, parameter int C = $clog2(DEPTH+1)
)
( input  logic         clk
, input  logic         rst

, output logic [C-1:0] o_count

, input  logic         i_valid
, output logic         o_ready
, input  logic [W-1:0] i_data

, output logic         o_valid
, input  logic         i_ready
, output logic [W-1:0] o_data
);

    logic [C-1:0] count;
    logic [A-1:0] wa, ra;
    logic [W-1:0] line [DEPTH];

    wire full      = count == A'(DEPTH);
    wire not_empty = count != A'('d0);

    assign o_ready = !full || i_ready;

    wire do_wr = i_valid && o_ready;
    wire do_rd = o_valid && i_ready;

    assign o_valid = not_empty;
    assign o_data = line[ra];

    assign o_count = count;

    always_ff @(posedge clk) begin
        if (rst) begin
            wa <= 0;
            ra <= 0;
            count <= 0;
        end else begin
            if (do_wr) begin
                line[wa] <= i_data;
                wa <= A'(wa + 'd1);
            end

            if (do_rd) begin
                ra <= A'(ra + 'd1);
            end

            case ({do_wr, do_rd})
                2'b10:   count <= C'(count + 'd1);
                2'b01:   count <= C'(count - 'd1);
                default: count <= count;
            endcase
        end
    end

endmodule : zerochan_fifo
