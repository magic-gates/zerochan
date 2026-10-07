module zerochan_skid #
( parameter int W = 8
)
( input  logic         clk
, input  logic         rst

, input  logic         i_valid
, output logic         o_ready
, input  logic [W-1:0] i_data

, output logic         o_valid
, input  logic         i_ready
, output logic [W-1:0] o_data
);

    logic         m_valid;
    logic [W-1:0] m_data;

    logic         s_valid;
    logic [W-1:0] s_data;

    assign o_valid = m_valid;
    assign o_data = m_data;
    assign o_ready = !s_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            m_valid <= 0;
            s_valid <= 0;
        end else begin
            if (i_ready) begin
                if (s_valid) begin
                    m_data <= s_data;
                    m_valid <= 1'b1;
                    s_valid <= 1'b0;
                end else begin
                    m_data <= i_data;
                    m_valid <= i_valid;
                end
            end else if (i_valid) begin
                if (!m_valid) begin
                    m_data  <= i_data;
                    m_valid <= 1'b1;
                end else begin
                    s_data  <= i_data;
                    s_valid <= 1'b1;
                end
            end
        end
    end

endmodule : zerochan_skid
