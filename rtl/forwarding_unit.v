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
    output wire [1:0] forward_a_ex,
    output wire [1:0] forward_b_ex,

    // Forwarding to ID stage (Branch Comparator / JALR)
    // 00: from Register File (no hazard)
    // 10: from EX/MEM
    // 01: from MEM/WB
    output wire [1:0] forward_a_id,
    output wire [1:0] forward_b_id
);
    assign forward_a_id = (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == if_id_rs1)) ? 2'b10 :
                          (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs1)) ? 2'b01 : 2'b00;

    assign forward_b_id = (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == if_id_rs2)) ? 2'b10 :
                          (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == if_id_rs2)) ? 2'b01 : 2'b00;

    assign forward_a_ex = (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) ? 2'b10 :
                          (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1)) ? 2'b01 : 2'b00;

    assign forward_b_ex = (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) ? 2'b10 :
                          (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2)) ? 2'b01 : 2'b00;
                        
endmodule
`default_nettype wire