module zerochan_skid #
( parameter int W = 8
)
( input  logic         clk
, input  logic         rst

, input  logic         s_valid
, output logic         s_ready
, input  logic [W-1:0] s_data

, output logic         m_valid
, input  logic         m_ready
, output logic [W-1:0] m_data
);

    logic         pm_valid;
    logic [W-1:0] pm_data;

    logic         sk_valid;
    logic [W-1:0] sk_data;

    assign m_valid = pm_valid;
    assign m_data = pm_data;
    assign s_ready = !sk_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            pm_valid <= 0;
            sk_valid <= 0;
        end else begin
            if (m_ready) begin
                if (sk_valid) begin
                    pm_data <= sk_data;
                    pm_valid <= 1'b1;
                    sk_valid <= 1'b0;
                end else begin
                    pm_data <= s_data;
                    pm_valid <= s_valid;
                end
            end else if (s_valid) begin
                if (!pm_valid) begin
                    pm_data  <= s_data;
                    pm_valid <= 1'b1;
                end else begin
                    sk_data  <= s_data;
                    sk_valid <= 1'b1;
                end
            end
        end
    end

endmodule : zerochan_skid
