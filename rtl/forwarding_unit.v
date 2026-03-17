`default_nettype none

module forwarding_unit (
    input wire [4:0] id_ex_rs1,
    input wire [4:0] id_ex_rs2,
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,
    input wire [4:0] ex_mem_rd,
    input wire [4:0] mem_wb_rd,
    input wire ex_mem_reg_write,
    input wire mem_wb_reg_write,

    // Forwarding to EX stage (ALU)
    // 00: from ID/EX (no hazard)
    // 10: from EX/MEM (prior ALU result)
    // 01: from MEM/WB (prior memory/ALU result)
    output reg [1:0] forward_a_ex,
    output reg [1:0] forward_b_ex,

    // Forwarding to ID stage (Branch Comparator / JALR)
    // 00: from Register File (no hazard)
    // 10: from EX/MEM
    // 01: from MEM/WB
    output reg [1:0] forward_a_id,
    output reg [1:0] forward_b_id
);

    always @(*) begin
        // --- Forwarding to EX Stage ---
        forward_a_ex = 2'b00;
        forward_b_ex = 2'b00;

        // EX Hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a_ex = 2'b10;
        end 
        // MEM Hazard
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1)) begin
            forward_a_ex = 2'b01;
        end

        // EX Hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b_ex = 2'b10;
        end 
        // MEM Hazard
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2)) begin
            forward_b_ex = 2'b01;
        end

        // --- Forwarding to ID Stage (For Early Branch Resolution) ---
        forward_a_id = 2'b00;
        forward_b_id = 2'b00;

        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == if_id_rs1)) begin
            forward_a_id = 2'b10;
        end else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs1)) begin
            forward_a_id = 2'b01;
        end

        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == if_id_rs2)) begin
            forward_b_id = 2'b10;
        end else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs2)) begin
            forward_b_id = 2'b01;
        end
    end

endmodule
`default_nettype wire