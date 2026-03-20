module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc,

    // Additional retire signals
    output wire [31:0] o_retire_dmem_addr,
    output wire o_retire_dmem_ren,
    output wire o_retire_dmem_wen,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);   

    // NOP Instruction (addi x0, x0, 0)
    localparam NOP_INST = 32'h00000013;

    // =========================================================================
    // PIPELINE REGISTERS
    // =========================================================================

    // PC Register (Not a pipeline register, but holds current fetch state)
    reg [31:0] pc_reg;

    // IF/ID Register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;
    reg        if_id_valid;

    // ID/EX Register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_inst;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    // ID/EX Control
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_alu_src;
    reg        id_ex_i_sub;
    reg        id_ex_i_unsigned;
    reg        id_ex_i_arith;
    reg [2:0]  id_ex_alu_op;
    reg        id_ex_lui;
    reg        id_ex_auipc;
    reg        id_ex_halt;
    reg        id_ex_valid;

    // EX/MEM Register
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_inst;
    reg [31:0] ex_mem_alu_res;
    reg [31:0] ex_mem_rs2_data; // For stores
    reg [4:0]  ex_mem_rd;
    // EX/MEM Control
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;
    reg        ex_mem_halt;
    reg        ex_mem_valid;
    // EX/MEM Tracking for retire
    reg [31:0] ex_mem_rs1_data_ret;
    reg [31:0] ex_mem_rs2_data_ret;

    // MEM/WB Register
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_inst;
    reg [31:0] mem_wb_alu_res;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_testmem_data;
    reg [4:0]  mem_wb_rd;
    // MEM/WB Control
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;
    reg        mem_wb_halt;
    reg        mem_wb_valid;
    // MEM/WB Retire Tracking
    reg [31:0] mem_wb_rs1_data_ret;
    reg [31:0] mem_wb_rs2_data_ret;
    reg [31:0] mem_wb_dmem_addr;
    reg        mem_wb_dmem_ren;
    reg        mem_wb_dmem_wen;
    reg [3:0]  mem_wb_dmem_mask;
    reg [31:0] mem_wb_dmem_wdata;
    reg [31:0] mem_wb_dmem_rdata;

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // =========================================================================
    
    wire pc_write;
    wire if_id_write;
    wire branch_taken; // Generated in ID
    wire [31:0] branch_target; // Generated in ID

    wire [31:0] pc_next = branch_taken ? branch_target : (pc_reg + 4);

    assign o_imem_raddr = pc_reg;

    always @(posedge i_clk) begin
        if (i_rst) begin
            pc_reg <= RESET_ADDR;
        end else if (pc_write) begin
            pc_reg <= pc_next;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst || branch_taken) begin
            if_id_pc    <= 0;
            if_id_inst  <= NOP_INST;
            if_id_valid <= 0;
        end else if (if_id_write) begin
            if_id_pc    <= pc_reg;
            if_id_inst  <= i_imem_rdata;
            if_id_valid <= 1;
        end
    end

    // =========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // =========================================================================

    wire [6:0] id_opcode = if_id_inst[6:0];
    wire [4:0] id_rs1    = if_id_inst[19:15];
    wire [4:0] id_rs2    = if_id_inst[24:20];
    wire [4:0] id_rd     = if_id_inst[11:7];
    
    // RF read
    wire [31:0] rf_read_data_1;
    wire [31:0] rf_read_data_2;
    wire [31:0] wb_write_data; // From WB stage

    rf  #(
        .BYPASS_EN(1'b1)
    ) rf (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(id_rs1),
        .i_rs2_raddr(id_rs2),
        .i_rd_wen(mem_wb_reg_write),
        .i_rd_waddr(mem_wb_rd),
        .i_rd_wdata(wb_write_data),
        .o_rs1_rdata(rf_read_data_1),
        .o_rs2_rdata(rf_read_data_2)
    );

    // Hazard and Forwarding logic signals
    wire ctrl_mux;
    wire [1:0] forward_a_id;
    wire [1:0] forward_b_id;

    // Forwarding Muxes for ID Stage (Branching/JALR)
    wire [31:0] id_forwarded_rs1 = (forward_a_id == 2'b10) ? ex_mem_alu_res :
                                   (forward_a_id == 2'b01) ? wb_write_data : rf_read_data_1;

    wire [31:0] id_forwarded_rs2 = (forward_b_id == 2'b10) ? ex_mem_alu_res :
                                   (forward_b_id == 2'b01) ? wb_write_data : rf_read_data_2;

    // Decode & Control
    wire id_i_sub, id_i_unsigned, id_i_arith, id_reg_write, id_mem_read, id_mem_write;
    wire id_branch, id_mem_to_reg, id_auipc, id_jump, id_jalr, id_alu_src, id_lui, id_halt;
    wire [2:0] id_alu_op;

    control_block ctrl (
        .opcode(id_opcode),
        .func_7(if_id_inst[31:25]),
        .func_3(if_id_inst[14:12]),
        .i_sub(id_i_sub), 
        .i_unsigned(id_i_unsigned),
        .i_arith(id_i_arith),
        .reg_write(id_reg_write),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .branch(id_branch),
        .mem_to_reg(id_mem_to_reg),
        .AUIPC(id_auipc),
        .jump(id_jump),
        .LUI(id_lui),
        .ALU_src(id_alu_src),
        .halt(id_halt),
        .ALU_opsel(id_alu_op),
        .JALR(id_jalr)
    );

    wire [5:0] id_format;
    instruction_type_decoder inst_decoder (
        .opcode(id_opcode),
        .instruction_format(id_format)
    );

    wire [31:0] id_imm;
    imm imm_gen (
        .i_inst(if_id_inst),
        .i_format(id_format),
        .o_immediate(id_imm)
    );

    // Early Branch Resolution (in ID)
    wire id_cmp_eq, id_cmp_slt;
    branch_comparator b_cmp (
        .op1(id_forwarded_rs1),
        .op2(id_forwarded_rs2),
        .i_unsigned(id_i_unsigned),
        .eq(id_cmp_eq),
        .slt(id_cmp_slt)
    );

    wire id_branch_condition;
    branch_control b_ctrl (
        .zero(id_cmp_eq),
        .slt(id_cmp_slt),
        .control_signal_branch(id_branch),
        .func_3(if_id_inst[14:12]),
        .branch(id_branch_condition)
    );

    wire is_branch_or_jalr_in_id = id_branch | id_jalr;

    hazard_detection_unit hdu (
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .is_branch_or_jalr_in_id(is_branch_or_jalr_in_id),
        .id_ex_reg_write(id_ex_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_rd(ex_mem_rd),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .ctrl_mux(ctrl_mux)
    );

    assign branch_taken  = id_branch_condition | id_jump | id_jalr;
    wire [31:0] branch_pc_base = id_jalr ? id_forwarded_rs1 : if_id_pc;
    assign branch_target = (branch_pc_base + id_imm) & 32'hffff_fffe;

    // ID/EX Pipeline Register Update
    always @(posedge i_clk) begin
        if (i_rst ) begin // Flush on stall OR branch     || ctrl_mux
            id_ex_pc         <= 0;
            id_ex_inst       <= NOP_INST;
            id_ex_rs1_data   <= 0;
            id_ex_rs2_data   <= 0;
            id_ex_imm        <= 0;
            id_ex_rs1        <= 0;
            id_ex_rs2        <= 0;
            id_ex_rd         <= 0;
            id_ex_reg_write  <= 0;
            id_ex_mem_read   <= 0;
            id_ex_mem_write  <= 0;
            id_ex_mem_to_reg <= 0;
            id_ex_alu_src    <= 0;
            id_ex_i_sub      <= 0;
            id_ex_i_unsigned <= 0;
            id_ex_i_arith    <= 0;
            id_ex_alu_op     <= 0;
            id_ex_lui        <= 0;
            id_ex_auipc      <= 0;
            id_ex_halt       <= 0;
            id_ex_valid      <= 0;
        end else begin
            id_ex_pc         <= if_id_pc;
            id_ex_inst       <= if_id_inst;
            id_ex_rs1_data   <= id_forwarded_rs1; // Pass forwarded data down for retirement!
            id_ex_rs2_data   <= id_forwarded_rs2;
            id_ex_imm        <= id_imm;
            id_ex_rs1        <= id_rs1;
            id_ex_rs2        <= id_rs2;
            id_ex_rd         <= id_rd;
            id_ex_reg_write  <= id_reg_write;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_alu_src    <= id_alu_src;
            id_ex_i_sub      <= id_i_sub;
            id_ex_i_unsigned <= id_i_unsigned;
            id_ex_i_arith    <= id_i_arith;
            id_ex_alu_op     <= id_alu_op;
            id_ex_lui        <= id_lui;
            id_ex_auipc      <= id_auipc;
            id_ex_halt       <= id_halt;
            id_ex_valid      <= if_id_valid;
        end
    end

    // =========================================================================
    // STAGE 3: EXECUTE (EX)
    // =========================================================================

    wire [1:0] forward_a_ex, forward_b_ex;
    
    forwarding_unit fwd (
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .ex_mem_rd(ex_mem_rd),
        .mem_wb_rd(mem_wb_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a_ex(forward_a_ex),
        .forward_b_ex(forward_b_ex),
        .forward_a_id(forward_a_id),
        .forward_b_id(forward_b_id)
    );

    wire [31:0] ex_forwarded_rs1 = (forward_a_ex == 2'b10) ? ex_mem_alu_res :
                                   (forward_a_ex == 2'b01) ? wb_write_data  : id_ex_rs1_data;

    wire [31:0] ex_forwarded_rs2 = (forward_b_ex == 2'b10) ? ex_mem_alu_res :
                                   (forward_b_ex == 2'b01) ? wb_write_data  : id_ex_rs2_data;

    wire [31:0] alu_op1 = id_ex_lui ? 32'b0 :
                          id_ex_auipc ? id_ex_pc : ex_forwarded_rs1;
                          
    wire [31:0] alu_op2 = id_ex_alu_src ? id_ex_imm : ex_forwarded_rs2;
    wire [31:0] ex_alu_res;
    wire unused_eq, unused_slt;

    alu core_alu (
        .i_opsel(id_ex_alu_op),
        .i_sub(id_ex_i_sub),
        .i_unsigned(id_ex_i_unsigned),
        .i_arith(id_ex_i_arith),
        .i_op1(alu_op1),
        .i_op2(alu_op2),
        .o_result(ex_alu_res),
        .o_eq(unused_eq),
        .o_slt(unused_slt)
    );

    // Because jumps were resolved in ID, if the instruction is JAL/JALR, 
    // we must write PC+4 to rd. We intercept the ALU result here.
    wire is_ex_jump = (id_ex_inst[6:0] == 7'b110_1111) || (id_ex_inst[6:0] == 7'b110_0111);
    wire [31:0] ex_stage_result = is_ex_jump ? (id_ex_pc + 4) : ex_alu_res;

    // EX/MEM Pipeline Register Update
    always @(posedge i_clk) begin
        if (i_rst) begin
            ex_mem_pc           <= 0;
            ex_mem_inst         <= NOP_INST;
            ex_mem_alu_res      <= 0;
            ex_mem_rs2_data     <= 0;
            ex_mem_rd           <= 0;
            ex_mem_reg_write    <= 0;
            ex_mem_mem_read     <= 0;
            ex_mem_mem_write    <= 0;
            ex_mem_mem_to_reg   <= 0;
            ex_mem_halt         <= 0;
            ex_mem_valid        <= 0;
            ex_mem_rs1_data_ret <= 0;
            ex_mem_rs2_data_ret <= 0;
        end else begin
            ex_mem_pc           <= id_ex_pc;
            ex_mem_inst         <= id_ex_inst;
            ex_mem_alu_res      <= ex_stage_result;
            ex_mem_rs2_data     <= ex_forwarded_rs2; // Data to store
            ex_mem_rd           <= id_ex_rd;
            ex_mem_reg_write    <= id_ex_reg_write;
            ex_mem_mem_read     <= id_ex_mem_read;
            ex_mem_mem_write    <= id_ex_mem_write;
            ex_mem_mem_to_reg   <= id_ex_mem_to_reg;
            ex_mem_halt         <= id_ex_halt;
            ex_mem_valid        <= id_ex_valid;
            ex_mem_rs1_data_ret <= ex_forwarded_rs1;
            ex_mem_rs2_data_ret <= ex_forwarded_rs2;
        end
    end

    // =========================================================================
    // STAGE 4: MEMORY (MEM)
    // =========================================================================

    wire [3:0] mem_dmem_mask;
    wire [31:0] mem_aligned_address;
    wire [31:0] mem_aligned_data;

    address_aligner addr_align (
        .func_3(ex_mem_inst[14:12]),
        .address(ex_mem_alu_res),
        .data(ex_mem_rs2_data),
        .mask(mem_dmem_mask),
        .aligned_address(mem_aligned_address),
        .aligned_data(mem_aligned_data)
    );

    // Drive Data Memory outputs from EX/MEM stage
    assign o_dmem_addr  = mem_aligned_address;
    assign o_dmem_ren   = ex_mem_mem_read;
    assign o_dmem_wen   = ex_mem_mem_write;
    assign o_dmem_mask  = mem_dmem_mask;
    assign o_dmem_wdata = mem_aligned_data; // Pre-aligned if needed by architecture (WISC standard relies on mask)

    wire [31:0] mem_aligned_rdata;
    wire [31:0] mem_testbench_rdata;

    data_aligner dat_align (
        .data(i_dmem_rdata),
        .mask(mem_dmem_mask),
        .func_3(ex_mem_inst[14:12]),
        .data_output(mem_aligned_rdata),
        .data_testbench_output(mem_testbench_rdata)
    );

    // MEM/WB Pipeline Register Update
    always @(posedge i_clk) begin
        if (i_rst) begin
            mem_wb_pc           <= 0;
            mem_wb_inst         <= NOP_INST;
            mem_wb_alu_res      <= 0;
            mem_wb_mem_data     <= 0;
            mem_wb_rd           <= 0;
            mem_wb_reg_write    <= 0;
            mem_wb_mem_to_reg   <= 0;
            mem_wb_halt         <= 0;
            mem_wb_valid        <= 0;
            mem_wb_rs1_data_ret <= 0;
            mem_wb_rs2_data_ret <= 0;
            mem_wb_dmem_addr    <= 0;
            mem_wb_dmem_ren     <= 0;
            mem_wb_dmem_wen     <= 0;
            mem_wb_dmem_mask    <= 0;
            mem_wb_dmem_wdata   <= 0;
            mem_wb_dmem_rdata   <= 0;
        end else begin
            mem_wb_pc           <= ex_mem_pc;
            mem_wb_inst         <= ex_mem_inst;
            mem_wb_alu_res      <= ex_mem_alu_res;
            mem_wb_mem_data     <= mem_aligned_rdata;
            mem_wb_testmem_data <= mem_testbench_rdata;
            mem_wb_rd           <= ex_mem_rd;
            mem_wb_reg_write    <= ex_mem_reg_write;
            mem_wb_mem_to_reg   <= ex_mem_mem_to_reg;
            mem_wb_halt         <= ex_mem_halt;
            mem_wb_valid        <= ex_mem_valid;
            mem_wb_rs1_data_ret <= ex_mem_rs1_data_ret;
            mem_wb_rs2_data_ret <= ex_mem_rs2_data_ret;
            
            // Pass the memory bus values down to WB for retirement logging
            mem_wb_dmem_addr    <= mem_aligned_address;
            mem_wb_dmem_ren     <= ex_mem_mem_read;
            mem_wb_dmem_wen     <= ex_mem_mem_write;
            mem_wb_dmem_mask    <= mem_dmem_mask;
            mem_wb_dmem_wdata   <= mem_aligned_data;
            mem_wb_dmem_rdata   <= mem_testbench_rdata;
        end
    end

    // =========================================================================
    // STAGE 5: WRITEBACK (WB) & RETIREMENT
    // =========================================================================

    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_res;

    // Retirement signals reflect the instruction finalizing Writeback
    assign o_retire_valid     = mem_wb_valid;
    assign o_retire_inst      = mem_wb_inst;
    assign o_retire_pc        = mem_wb_pc;
    assign o_retire_next_pc   = mem_wb_pc + 4; // Approximated per instruction for pipeline log
    assign o_retire_halt      = mem_wb_halt;
    assign o_retire_trap      = 0; // Not implemented in base provided spec

    assign o_retire_rs1_raddr = mem_wb_inst[19:15];
    assign o_retire_rs2_raddr = mem_wb_inst[24:20];
    assign o_retire_rs1_rdata = mem_wb_rs1_data_ret;
    assign o_retire_rs2_rdata = mem_wb_rs2_data_ret;

    wire wb_is_rd_valid = (mem_wb_inst[6:0] == 7'b011_0111 || mem_wb_inst[6:0] == 7'b001_0111 || 
                           mem_wb_inst[6:0] == 7'b110_1111 || mem_wb_inst[6:0] == 7'b110_0111 || 
                           mem_wb_inst[6:0] == 7'b000_0011 || mem_wb_inst[6:0] == 7'b001_0011 || 
                           mem_wb_inst[6:0] == 7'b011_0011);

    assign o_retire_rd_waddr  = wb_is_rd_valid ? mem_wb_rd : 5'd0;
    assign o_retire_rd_wdata  = mem_wb_reg_write ? wb_write_data : 32'd0;

    // New Memory signals wired to Writeback pipeline register
    assign o_retire_dmem_addr  = mem_wb_dmem_addr;
    assign o_retire_dmem_ren   = mem_wb_dmem_ren;
    assign o_retire_dmem_wen   = mem_wb_dmem_wen;
    assign o_retire_dmem_mask  = mem_wb_dmem_mask;
    assign o_retire_dmem_wdata = mem_wb_dmem_wdata;
    assign o_retire_dmem_rdata = mem_wb_testmem_data;

endmodule

`default_nettype wire