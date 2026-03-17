`default_nettype none

module hazard_detection_unit (
    input wire id_ex_mem_read,
    input wire [4:0] id_ex_rd,
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,
    
    input wire is_branch_or_jalr_in_id,
    input wire id_ex_reg_write,
    input wire ex_mem_mem_read,
    input wire [4:0] ex_mem_rd,

    output reg pc_write,
    output reg if_id_write,
    output reg ctrl_mux 
);

    always @(*) begin
        pc_write = 1;
        if_id_write = 1;
        ctrl_mux = 0;

        // FIX: Added (id_ex_rd != 0) so we don't stall on x0 dependencies
        if (id_ex_mem_read && (id_ex_rd != 0) && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            pc_write = 0;
            if_id_write = 0;
            ctrl_mux = 1;
        end

        if (is_branch_or_jalr_in_id) begin
            if (id_ex_reg_write && (id_ex_rd != 0) && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
                pc_write = 0;
                if_id_write = 0;
                ctrl_mux = 1;
            end
            if (ex_mem_mem_read && (ex_mem_rd != 0) && ((ex_mem_rd == if_id_rs1) || (ex_mem_rd == if_id_rs2))) begin
                pc_write = 0;
                if_id_write = 0;
                ctrl_mux = 1;
            end
        end
    end
endmodule
`default_nettype wire