module zerochan_tx #
( parameter int unsigned DW = 12
, parameter int unsigned DATA_LEN = 480
, parameter int unsigned UW_LEN = 32

, parameter string UW_INIT = "uw.mem"
)
( input  logic                 clk
, input  logic                 rst

, input  logic                 s_valid
, output logic                 s_ready
, input  logic signed [DW-1:0] s_re
, input  logic signed [DW-1:0] s_im

, output logic                 m_valid
, input  logic                 m_ready
, output logic signed [DW-1:0] m_re
, output logic signed [DW-1:0] m_im
);

    localparam int DATA_C = $clog2(DATA_LEN);
    localparam int UW_C = $clog2(UW_LEN);

    localparam logic signed [DW-1:0] DW_P = $signed({1'b0, {(DW-1){1'b1}}});
    localparam logic signed [DW-1:0] DW_N = $signed({1'b1, {(DW-2){1'b0}}, 1'b1});

    logic signed [DW-1:0] ps_re, ps_im;
    logic ps_valid, ps_ready;

    logic [1:0] uw_rom [UW_LEN];

    enum logic { DT, UW } state;

    logic [DATA_C-1:0] data_cnt;
    logic [UW_C-1:0] uw_cnt;

    logic signed [DW-1:0] uw_re, uw_im;

    initial $readmemb(UW_INIT, uw_rom);

    // Map UW constellation points
    always_comb begin
        unique case (uw_rom[uw_cnt])
            2'b00: {uw_re, uw_im} = {DW_P, DW_P};
            2'b01: {uw_re, uw_im} = {DW_P, DW_N};
            2'b10: {uw_re, uw_im} = {DW_N, DW_P};
            2'b11: {uw_re, uw_im} = {DW_N, DW_N};
        endcase
    end

    always_comb begin
        if (state == DT) begin
            s_ready = ps_ready;
            ps_valid = s_valid;
            {ps_re, ps_im} = {s_re, s_im};
        end else begin
            s_ready = 1'b0;
            ps_valid = 1'b1;
            {ps_re, ps_im} = {uw_re, uw_im};
        end
    end

    // Feed Data, UW, Data, UW ...
    always_ff @(posedge clk) begin
        if (rst) begin
            data_cnt <= 0;
            uw_cnt <= 0;
            state <= DT;
        end else unique case (state)
            DT: if (ps_valid && ps_ready) begin
                if (data_cnt == DATA_C'(DATA_LEN - 1)) begin
                    state <= UW;
                    data_cnt <= 0;
                end else begin
                    data_cnt <= DATA_C'(data_cnt + 'd1);
                end
            end
            UW: if (ps_valid && ps_ready) begin
                if (uw_cnt == UW_C'(UW_LEN - 1)) begin
                    state <= DT;
                    uw_cnt <= 0;
                end else begin
                    uw_cnt <= UW_C'(uw_cnt + 'd1);
                end
            end
        endcase
    end

    // Pulse shaping filter
    zerochan_ps_tx #(DW) u_ps
    ( .clk(clk)
    , .rst(rst)

    , .s_valid(ps_valid)
    , .s_ready(ps_ready)
    , .s_re(ps_re)
    , .s_im(ps_im)

    , .m_valid(m_valid)
    , .m_ready(m_ready)
    , .m_re(m_re)
    , .m_im(m_im)
    );

    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, zerochan_tx);
    end

endmodule : zerochan_tx
