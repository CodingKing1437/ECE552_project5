`default_nettype none

module branch_comparator(
    input wire [31:0] op1, 
    input wire [31:0] op2,
    input wire i_unsigned,
    output wire eq, 
    output wire slt
);
    assign eq = (op1 == op2);
    
    wire sign1 = op1[31];
    wire sign2 = op2[31];
    
    wire slt_signed = (sign1 & ~sign2) | (~(sign1 ^ sign2) & (op1 < op2));
    wire slt_unsigned = (op1 < op2);
    
    assign slt = i_unsigned ? slt_unsigned : slt_signed;
endmodule
`default_nettype wire