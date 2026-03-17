`default_nettype none

module control_block(
    // 7-bit opcode from instruction word
    input wire [6:0] opcode,
    input wire [6:0] func_7,
    input wire [2:0] func_3,
    
    // ALU Modifiers
    output wire i_sub,
    output wire i_unsigned,
    output wire i_arith,
    
    // Core Control Signals
    output wire reg_write,
    output wire mem_read,
    output wire mem_write,
    output wire branch,
    output wire mem_to_reg,
    output wire AUIPC,
    output wire LUI,
    output wire halt,
    output wire [2:0] ALU_opsel,
    
    // NEW PIPELINE CONTROL SIGNALS
    output wire jump,
    output wire JALR,
    output wire ALU_src
);

    assign AUIPC = (opcode == 7'b001_0111) ? 1'b1 : 1'b0;
    assign LUI   = (opcode == 7'b011_0111) ? 1'b1 : 1'b0;
    assign halt  = (opcode == 7'b111_0011) ? 1'b1 : 1'b0;

    // ALU opsel: 000 for ADD. Use func_3 directly for all other arithmetic types
    assign ALU_opsel = (opcode == 7'b011_0011 | opcode == 7'b001_0011) ? func_3 : 3'b000;

    // Reg write: All instructions write to a register EXCEPT Branch (1100011), Store (0100011), and Halt
    assign reg_write = ((opcode != 7'b010_0011) && (opcode != 7'b110_0011) && (opcode != 7'b111_0011)) ? 1'b1 : 1'b0;

    assign mem_read   = (opcode == 7'b000_0011) ? 1'b1 : 1'b0;
    assign mem_write  = (opcode == 7'b010_0011) ? 1'b1 : 1'b0;
    assign branch     = (opcode == 7'b110_0011) ? 1'b1 : 1'b0;
    assign mem_to_reg = (opcode == 7'b000_0011) ? 1'b1 : 1'b0;

    // --- ALU Modifiers ---
    // i_sub: Subtraction is used in branch comparisons OR R-type SUB (opcode 0110011, func3 000, func7 0100000)
    assign i_sub = (opcode == 7'b110_0011) || (opcode == 7'b011_0011 && func_3 == 3'b000 && func_7 == 7'b010_0000);
    
    // i_unsigned: Used in BLTU, BGEU (func3 110 or 111) and SLTIU/SLTU (func3 011)
    assign i_unsigned = (opcode == 7'b110_0011 && (func_3 == 3'b110 || func_3 == 3'b111)) ||
                        ((opcode == 7'b011_0011 || opcode == 7'b001_0011) && func_3 == 3'b011);

    // i_arith: Used in SRA/SRAI (func3 101, func7 0100000)
    assign i_arith = ((opcode == 7'b011_0011 || opcode == 7'b001_0011) && func_3 == 3'b101 && func_7 == 7'b010_0000);

    // --- NEW PIPELINE SIGNALS ---
    
    // JAL (1101111)
    assign jump = (opcode == 7'b110_1111) ? 1'b1 : 1'b0;
    
    // JALR (1100111)
    assign JALR = (opcode == 7'b110_0111) ? 1'b1 : 1'b0;

    // general is_jump signal
    assign is_jump = (opcode == 7'b110_1111 | opcode == 7'b110_0111) ? 1 : 0;

    // ALU_src is 1 when the second ALU operand needs to be an immediate instead of a register.
    // This includes: I-type Arithmetic, Loads, Stores, LUI, and AUIPC.
    assign ALU_src = (opcode == 7'b001_0011 || 
                      opcode == 7'b000_0011 || 
                      opcode == 7'b010_0011 || 
                      opcode == 7'b011_0111 || 
                      opcode == 7'b001_0111) ? 1'b1 : 1'b0;

endmodule

`default_nettype wire