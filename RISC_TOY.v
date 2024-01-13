/*****************************************
    
    Team 19 : 
        2018100720    Yoon Dongwan
        2019103999    Yu Hyunyoung 
*****************************************/


// You are able to add additional modules and instantiate in RISC_TOY.
// Please note that you should include those modules together in 'prj2.f' to properly compile the file.


////////////////////////////////////
//  TOP MODULE
////////////////////////////////////
module RISC_TOY (
    input     wire              CLK,
    input     wire              RSTN,
    output    wire              IREQ,
    output    wire    [29:0]    IADDR,
    input     wire    [31:0]    INSTR,
    output    wire              DREQ,
    output    wire              DRW,
    output    wire    [29:0]    DADDR,
    output    wire    [31:0]    DWDATA,
    input     wire    [31:0]    DRDATA
);

localparam [4:0] ADDI = 5'd0,
      ANDI = 5'd1,
      ORI = 5'd2,
      MOVI = 5'd3,
      ADD = 5'd4,
      SUB = 5'd5,
      NEG = 5'd6,
      NOT = 5'd7,
      AND = 5'd8,
      OR = 5'd9,
      XOR = 5'd10,
      LSR = 5'd11,
      ASR = 5'd12,
      SHL = 5'd13,
      ROR = 5'd14,
      BR = 5'd15,
      BRL = 5'd16,
      J = 5'd17,
      JL = 5'd18,
      LD = 5'd19,
      LDR = 5'd20,
      ST = 5'd21,
      STR = 5'd22;

    //PC
    reg PC_enable;
    reg PC_control;
    reg PC_stop;

    assign IREQ = 1;
    reg[31:0] PC_jump;

    reg[31:0] PC;
    wire[31:0] PC_in;
    reg r_PC_stop;
   always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            r_PC_stop <= 32'b0;
        else 
            r_PC_stop <= PC_stop;
   end
    wire pedge_PC_stop = !r_PC_stop && PC_stop;

   always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            PC <= 32'b0;
        else if(PC_enable)
            PC <= PC_in;
        else
            PC <= PC;
    end

    assign IADDR = PC_control_j ? PC[29:0]: (PC_enable ? PC[29:0]: PC[29:0] -4);
    //wire[31:0] w_PC = PC + 4;
    wire[31:0] w_PC = PC +4;
    assign PC_in = PC_control_j ? PC_jump_j :(PC_control ? PC_jump : w_PC);
   

   always@(*) begin
   if(pedge_PC_stop || hazard)
      PC_enable = 0;
   else
      PC_enable = 1;
   end



    //IF.ID pipeline
    /*
    reg[31:0] IF_ID_instr;
    
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            IF_ID_instr <= 32'b0;
        else
            IF_ID_instr <= INSTR;
    end
    */
    wire[31:0] IF_ID_instr = INSTR;
    reg[31:0] IF_ID_PC;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            IF_ID_PC<= 32'b0;
        else
            IF_ID_PC <= w_PC;
    end

    //INSTRUCTION DECODING STAGE
    wire[4:0] IF_ID_opcode = IF_ID_instr[31:27];
    wire[4:0] IF_ID_ra = IF_ID_instr[26:22];  //destination register
    wire[4:0] IF_ID_rb = IF_ID_instr[21:17];
    wire[4:0] IF_ID_rc = IF_ID_instr[16:12];
    wire[16:0] IF_ID_imm17 = IF_ID_instr[16:0];
    wire IF_ID_i = IF_ID_instr[5];
    wire [4:0] IF_ID_shamt = IF_ID_instr[4:0];
    wire [2:0] IF_ID_cond = IF_ID_instr[2:0];
    wire [21:0] IF_ID_imm22 = IF_ID_instr[21:0];

    reg data_hazard;
    wire hazard = data_hazard;
   /*
   reg r_data_hazard;
   
   always @(posedge CLK) begin
      r_data_hazard <= data_hazard;
   end
   */
    //Branch control -> stall
    always@(*)begin
      if((IF_ID_opcode == 5'b01111) || (IF_ID_opcode == 5'b10000)) begin
            PC_stop = 1;
        end
        else begin
            PC_stop = 0;
        end
    end

    reg PC_control_j;
    reg[31:0] PC_jump_j;
    always@(*)begin
      if((IF_ID_opcode == 5'b10001) || (IF_ID_opcode == 5'b10010)) begin
           PC_control_j = 1;
           PC_jump_j = IF_ID_PC + {{10{IF_ID_imm22[21]}},IF_ID_imm22};
        end
        else begin
            PC_control_j = 0;
        end
    end



    // REGISTER FILE FOR GENRAL PURPOSE REGISTERS
    // register memory
    wire [31:0] IF_ID_w_valB;
    reg [31:0] IF_ID_Rra;
    wire [31:0] IF_ID_Rrb;
    reg [31:0] IF_ID_Rrc;

    reg [4:0] IF_ID_raddr1;
    always@(*) begin
        if(IF_ID_opcode == 5'b10101 || IF_ID_opcode == 5'b10110)
            IF_ID_raddr1 = IF_ID_ra;
        else
            IF_ID_raddr1 = IF_ID_rc;
    end
    always@(*) begin
        if(IF_ID_opcode == 5'b10101 || IF_ID_opcode == 5'b10110)
            IF_ID_Rra = IF_ID_w_valB;
        else
            IF_ID_Rrc = IF_ID_w_valB;
        
    end


    REGFILE    #(.AW(5), .ENTRY(32))    RegFile (
                    .CLK    (CLK),
                    .RSTN   (RSTN),
                    .WEN    (r_WEN),
                    .WA     (r_WA),
                    .DI     (r_DI),
                    .RA0    (IF_ID_rb),
                    .RA1    (IF_ID_raddr1),
                    .DOUT0  (IF_ID_Rrb),
                    .DOUT1  (IF_ID_w_valB)
    );
    

    //ID.EX pipeline
    reg[31:0] ID_EX_Rra, ID_EX_Rrb, ID_EX_Rrc;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            ID_EX_Rra <= 32'b0;
            ID_EX_Rrb <= 32'b0;
            ID_EX_Rrc <= 32'b0;
        end
        else begin
            ID_EX_Rra <= IF_ID_Rra;
            ID_EX_Rrb <= IF_ID_Rrb;
            ID_EX_Rrc <= IF_ID_Rrc;
        end
    end
    
    reg[31:0] ID_EX_PC;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_PC <= 32'b0;
        else if(pedge_PC_stop)
            ID_EX_PC <= IF_ID_PC - 4;
        else
            ID_EX_PC <= IF_ID_PC;
    end

    reg[4:0] ID_EX_opcode;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_opcode <= 5'b0;
        else
            ID_EX_opcode <= IF_ID_opcode;
    end

    reg[4:0] ID_EX_rb;
    reg[4:0] ID_EX_ra;      //destination register
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            ID_EX_rb <= 5'b0;
            ID_EX_ra <= 5'b0;
        end
        else begin
            ID_EX_rb <= IF_ID_rb;
            ID_EX_ra <= IF_ID_ra;
        end
    end
    
    reg[16:0] ID_EX_imm17;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_imm17 <= 17'b0;
        else
            ID_EX_imm17 <= IF_ID_imm17;
    end

    reg ID_EX_i;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_i <= 1'b0;
        else
            ID_EX_i <= IF_ID_i;
    end

    reg [4:0] ID_EX_shamt;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_shamt <= 5'b0;
        else
            ID_EX_shamt <= IF_ID_shamt;
    end
    
    reg [2:0] ID_EX_cond;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_cond <= 3'b0;
        else
            ID_EX_cond <= IF_ID_cond;
    end
    
    reg [21:0] ID_EX_imm22;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            ID_EX_imm22 <= 22'b0;
        else
            ID_EX_imm22 <= IF_ID_imm22;
    end

    

//ID_EX_Rra, ID_EX_Rrb, ID_EX_Rrc;
    //EXCUTE STAGE   
   reg [4:0] shift_reg;   
   reg [31:0] ALU_out;
   reg signed [31:0] ID_EX_Rrb_signed;

   always @(*) begin
        PC_control = 0;         //jump방지를 위해 default로 0을 해줘야함.
        case(ID_EX_opcode)
        ADDI: ALU_out = ID_EX_Rrb + {{15{ID_EX_imm17[16]}},ID_EX_imm17}; 
        ANDI: ALU_out = ID_EX_Rrb & {{15{ID_EX_imm17[16]}},ID_EX_imm17};
        ORI: ALU_out = ID_EX_Rrb | {{15{ID_EX_imm17[16]}},ID_EX_imm17};
        MOVI: ALU_out = {{15{ID_EX_imm17[16]}},ID_EX_imm17};      
        ADD: ALU_out = ID_EX_Rrb + ID_EX_Rrc; 
        SUB: ALU_out = ID_EX_Rrb - ID_EX_Rrc;
        NEG: ALU_out = - ID_EX_Rrc;       
        NOT: ALU_out = ~ ID_EX_Rrc; 
        AND: ALU_out = ID_EX_Rrb & ID_EX_Rrc;
        OR: ALU_out = ID_EX_Rrb | ID_EX_Rrc;
        XOR: ALU_out = ID_EX_Rrb ^ ID_EX_Rrc;
        LSR: begin 
            if (ID_EX_i == 0) begin
               ALU_out = ID_EX_Rrb >> ID_EX_shamt; 
         end
            else begin
               shift_reg = ID_EX_Rrc[4:0];
               ALU_out = ID_EX_Rrb >> shift_reg;
            end
         end
         ASR: begin
         ID_EX_Rrb_signed = ID_EX_Rrb;
            if (ID_EX_i == 0) begin
               ALU_out = ID_EX_Rrb_signed >>> ID_EX_shamt; 
            end
            else begin
               shift_reg = ID_EX_Rrc[4:0];
                ALU_out = ID_EX_Rrb_signed >>> shift_reg;
            end
         end
         
         SHL: begin 
            if (ID_EX_i == 0) begin
            ALU_out = ID_EX_Rrb << ID_EX_shamt; 
         end
            else begin
               shift_reg = ID_EX_Rrc[4:0];
               ALU_out = ID_EX_Rrb << shift_reg;
            end
         end
         
         ROR: begin 
            if (ID_EX_i == 0) begin
               ALU_out = (ID_EX_Rrb >> ID_EX_shamt) | (ID_EX_Rrb << (32 - ID_EX_shamt));
         end
            else begin
               shift_reg = ID_EX_Rrc[4:0];
               ALU_out = (ID_EX_Rrb >> shift_reg) | (ID_EX_Rrb << (32 - shift_reg));
            end
         end
         
         BR: begin
            if(ID_EX_cond == 3'd0) begin
                PC_control = 0;
            end
            else if(ID_EX_cond == 3'd1) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd2 && ID_EX_Rrc == 3'd0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd3 && ID_EX_Rrc != 3'd0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd4 && ID_EX_Rrc[31] == 1'b0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd5 && ID_EX_Rrc[31] == 1'b1) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else begin
                PC_control = 0;
            end
         end
         
         BRL: begin
            ALU_out = ID_EX_PC - 4;      //ALU_out control해줘야함...
            if(ID_EX_cond == 3'd0) begin
                PC_control = 0;
            end
            else if(ID_EX_cond == 3'd1) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd2 && ID_EX_Rrc == 3'd0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd3 && ID_EX_Rrc != 3'd0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd4 && ID_EX_Rrc[31] == 1'b0) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else if(ID_EX_cond == 3'd5 && ID_EX_Rrc[31] == 1'b1) begin
                PC_jump = ID_EX_Rrb;
                PC_control = 1;
            end
            else begin
                PC_control = 0;
            end
         end
         J : begin

         end

         JL : begin 
            ALU_out = ID_EX_PC -4;      //ALU_out control해줘야함...
         end

         LD: begin                                      //나중에 메모리 접근해야함.
               if (ID_EX_rb == 5'b11111) 
                    ALU_out = {{15{1'b0}},ID_EX_imm17};
               else 
                    ALU_out = {{15{ID_EX_imm17[16]}},ID_EX_imm17} + ID_EX_Rrb;
            end

         LDR: ALU_out = (ID_EX_PC - 4) + {{10{ID_EX_imm22[21]}},ID_EX_imm22};   //나중에 메모리 접근해야함.
         
         ST:   begin                //나중에 메모리 접근해야함.
               if (ID_EX_rb == 5'b11111) 
                    ALU_out = {{15{1'b0}},ID_EX_imm17};
               else 
                    ALU_out = {{15{ID_EX_imm17[16]}},ID_EX_imm17} + ID_EX_Rrb;
            end
            
         STR:    ALU_out = (ID_EX_PC - 4) + {{10{ID_EX_imm22[21]}},ID_EX_imm22};
       
         default: begin
            ALU_out = 0;
            PC_control = 0;
         end
        endcase
   end
   reg ID_EX_WB_valid; //OPCODE에 따라 REGISTER WRITE하는 경우 -> for hazard detection
   always@(*) begin
        if(ID_EX_opcode ==  5'b01111 || ID_EX_opcode ==  5'b10001 || ID_EX_opcode ==  5'b10101 || ID_EX_opcode ==  5'b10110)
            ID_EX_WB_valid = 0;
        else
            ID_EX_WB_valid = 1;
   end

/////////////////////////

    //EX.MEM pipeline
    reg[31:0] EX_MEM_Rra, EX_MEM_Rrb, EX_MEM_Rrc;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            EX_MEM_Rra <= 32'b0;
            EX_MEM_Rrb <= 32'b0;
            EX_MEM_Rrc <= 32'b0;
        end
        else begin
            EX_MEM_Rra <= ID_EX_Rra;
            EX_MEM_Rrb <= ID_EX_Rrb;
            EX_MEM_Rrc <= ID_EX_Rrc;
        end
    end

    reg[31:0] EX_MEM_PC;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            EX_MEM_PC <= 32'b0;
        else
            EX_MEM_PC <= ID_EX_PC;
    end

    reg[4:0] EX_MEM_opcode;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            EX_MEM_opcode <= 5'b0;
        else
            EX_MEM_opcode <= ID_EX_opcode;
    end

    reg[4:0] EX_MEM_ra; //destination
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            EX_MEM_ra <= 5'b0;
        end
        else begin
            EX_MEM_ra <= ID_EX_ra;
        end
    end

    reg [31:0] EX_MEM_ALU_out;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            EX_MEM_ALU_out <= 32'b0;
        end
        else begin
            EX_MEM_ALU_out <= ALU_out;   
        end
    end

   reg EX_MEM_WB_valid; //OPCODE에 따라 REGISTER WRITE하는 경우 -> for hazard detection
   always@(*) begin
        if(EX_MEM_opcode ==  5'b01111 || EX_MEM_opcode ==  5'b10001|| EX_MEM_opcode ==  5'b10101 || EX_MEM_opcode ==  5'b10110)
            EX_MEM_WB_valid = 0;
        else
            EX_MEM_WB_valid = 1;
   end
//MEMORY STAGE
//0~14 R[ra] = ALU_out  -> write back       -> register에서 나온거 wb
//15~18 pc = ALU_out //delay 필요함.  -> stall한번 필요
//19,20  R[ra] = M[ALU_out]     -> memory read write back   메모리에서 바로 wb
//21,22 M[ALU_out] = R[ra]      -> memmory write
reg r_DREQ; //-> active high         CSN
reg r_DRW;  //-> WEN            1 -> write, 0 -> read

always@(*) begin
    if(EX_MEM_opcode >=5'b10011)
        r_DREQ = 1'b1;
    else
        r_DREQ = 1'b0;
end

always@(*) begin
    if(EX_MEM_opcode == 5'b10101 || EX_MEM_opcode == 5'b10110)
        r_DRW = 1'b1;
    else
        r_DRW = 1'b0;
end

assign DREQ = r_DREQ;
assign DRW = r_DRW;
assign DADDR = EX_MEM_ALU_out;
assign DWDATA = EX_MEM_Rra;


//MEM.WB pipeline
//DRDATA
    reg[31:0] MEM_WB_ALU_out;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            MEM_WB_ALU_out <= 32'b0;
        end
        else begin
            MEM_WB_ALU_out <= EX_MEM_ALU_out;   
        end
    end

    reg[4:0] MEM_WB_opcode;
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN)
            MEM_WB_opcode <= 5'b0;
        else
            MEM_WB_opcode <= EX_MEM_opcode;
    end

    reg[4:0] MEM_WB_ra; //destination
    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            MEM_WB_ra <= 5'b0;
        end
        else begin
            MEM_WB_ra <= EX_MEM_ra;
        end
    end    

   reg MEM_WB_WB_valid; //OPCODE에 따라 REGISTER WRITE하는 경우 -> for hazard detection
   always@(*) begin
        if(MEM_WB_opcode ==  5'b01111 || MEM_WB_opcode ==  5'b10001 || MEM_WB_opcode ==  5'b10101 || MEM_WB_opcode ==  5'b10110)
            MEM_WB_WB_valid = 0;
        else
            MEM_WB_WB_valid = 1;
   end

    //WRITE BACK STAGE
    //0~14 R[ra] = ALU_out  -> write back       -> register에서 나온거 wb
    //15~18 pc = ALU_out //delay 필요함.  -> stall한번 필요
    //19,20  R[ra] = M[ALU_out]     -> memory read write back   메모리에서 바로 wb
    //21,22 M[ALU_out] = R[ra]      -> memmory write
    reg r_WEN;
    wire [4:0] r_WA = MEM_WB_ra;
    reg [31:0] r_DI;
    always@(*) begin
        if(MEM_WB_opcode >= 5'd0 && MEM_WB_opcode <= 5'd14) begin
            r_WEN  = 0;
            r_DI = MEM_WB_ALU_out;
        end
        else if(MEM_WB_opcode == 5'b10011 || MEM_WB_opcode == 5'b10100) begin
            r_WEN = 0;
            r_DI = DRDATA;
        end
        else if(MEM_WB_opcode == 5'b10000 || MEM_WB_opcode == 5'b10010) begin
            r_WEN = 0;
            r_DI = MEM_WB_ALU_out;
        end
        else begin
            r_WEN = 1;
        end
    end
   
    //for hazard detection
    reg[4:0] WB_opcode;
    reg[4:0] WB_ra;

    always@(posedge CLK, negedge RSTN) begin
        if(!RSTN) begin
            WB_opcode <= 0;
            WB_ra <= 0;
        end
        else begin
            WB_ra <= MEM_WB_ra;
            WB_opcode <= MEM_WB_opcode;
        end
    end

    reg WB_WB_valid; //OPCODE에 따라 REGISTER WRITE하는 경우 -> for hazard detection
   always@(*) begin
        if(WB_opcode ==  5'b01111 || WB_opcode ==  5'b10001 || WB_opcode ==  5'b10101 || WB_opcode ==  5'b10110)
            WB_WB_valid = 0;
        else
            WB_WB_valid = 1;
   end


   /////////////////////////data hazard detection/////////////////////////
   always @(*) begin
      //ADDI, ANDI, ORI
      //R[rb] 사용
      if (IF_ID_opcode == 5'b00000 || IF_ID_opcode == 5'b00001 || IF_ID_opcode == 5'b00010) begin 
         if ((ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
            data_hazard = 1;
         else if ((EX_MEM_ra == IF_ID_rb) && EX_MEM_WB_valid)
            data_hazard = 1;
         else if ((MEM_WB_ra == IF_ID_rb) && MEM_WB_WB_valid)
            data_hazard = 1;
         //else if ((WB_ra == IF_ID_rb) && WB_WB_valid)
         //   data_hazard = 1;
         else 
            data_hazard = 0;
         
      end
      //ADD, SUB, AND, OR, XOR
      //R[rb], R[rc] 사용
      else if (IF_ID_opcode == 5'b00100 || IF_ID_opcode == 5'b00101 || IF_ID_opcode == 5'b01000 || IF_ID_opcode == 5'b01001 || IF_ID_opcode == 5'b01010) begin 
         if ((ID_EX_ra == IF_ID_raddr1 || ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
            data_hazard = 1;
         else if ((EX_MEM_ra == IF_ID_raddr1 || EX_MEM_ra == IF_ID_rb) && EX_MEM_WB_valid)
            data_hazard = 1;
         else if ((MEM_WB_ra == IF_ID_raddr1 || MEM_WB_ra == IF_ID_rb) && MEM_WB_WB_valid)
            data_hazard = 1;
         //else if ((WB_ra == IF_ID_raddr1 || WB_ra == IF_ID_rb) && WB_WB_valid)
         //   data_hazard = 1;
         else
            data_hazard = 0;
      end
      
      //NEG, NOT
      //R[rc] 사용
      else if (IF_ID_opcode == 5'b00110 || IF_ID_opcode == 5'b00111) begin 
         if ((ID_EX_ra == IF_ID_raddr1) && ID_EX_WB_valid)
            data_hazard = 1;
         else if ((EX_MEM_ra == IF_ID_raddr1)&& EX_MEM_WB_valid)
            data_hazard = 1;
         else if ((MEM_WB_ra == IF_ID_raddr1)&& MEM_WB_WB_valid)
            data_hazard = 1;
         //else if ((WB_ra == IF_ID_raddr1)&& WB_WB_valid)
         //   data_hazard = 1;
         else
            data_hazard = 0;
      end
      
      //LSR, ASR, SHL,ROR -> 조건에 따라 R[rb] 또는 R[rc] R[rb] 사용
      else if (IF_ID_opcode == 5'b01011 || IF_ID_opcode == 5'b01100 || IF_ID_opcode == 5'b01101 || IF_ID_opcode == 5'b01110) begin
         if (IF_ID_i == 0) begin //R[rb] 사용
            if ((ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
               data_hazard = 1;
            else if ((EX_MEM_ra == IF_ID_rb)&& EX_MEM_WB_valid)
               data_hazard = 1;
            else if ((MEM_WB_ra == IF_ID_rb)&& MEM_WB_WB_valid)
               data_hazard = 1;
       //     else if ((WB_ra == IF_ID_rb) && WB_WB_valid)
        //        data_hazard = 1;
            else 
               data_hazard = 0;
         end
         else begin //R[rb] R[rc] 사용
            if ((ID_EX_ra == IF_ID_raddr1 || ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
               data_hazard = 1;
            else if ((EX_MEM_ra == IF_ID_raddr1 || EX_MEM_ra == IF_ID_rb)&& EX_MEM_WB_valid)
               data_hazard = 1;
            else if ((MEM_WB_ra == IF_ID_raddr1 || MEM_WB_ra == IF_ID_rb)&& MEM_WB_WB_valid)
               data_hazard = 1;
        //    else if((WB_ra == IF_ID_raddr1 || WB_ra == IF_ID_rb ) && WB_WB_valid)
       //         data_hazard = 1;
            else
               data_hazard = 0;
         end
      end
      /*
      //BR, BRL -> 조건에 따라 PC <= R[rb]와 R[rc] 사용
      else if (IF_ID_opcode == 5'b01111 || IF_ID_opcode == 5'b10000) begin
         if (ID_EX_cond == 3'd2 || ID_EX_cond == 3'd3 || ID_EX_cond == 3'd4 || ID_EX_cond == 3'd5) begin
            if (ID_EX_ra == IF_ID_raddr1 || ID_EX_ra == IF_ID_rb)
               data_hazard = 1;
            else if (EX_MEM_ra == IF_ID_raddr1 || EX_MEM_ra == IF_ID_rb)
               data_hazard = 1;
            else if (MEM_WB_ra == IF_ID_raddr1 || MEM_WB_ra == IF_ID_rb)
               data_hazard = 1;
            else
               data_hazard = 0;
         end
        */

        //BR, BRL -> 조건에 따라 PC <= R[rb]와 R[rc] 사용
      /*else if (IF_ID_opcode == 5'b01111 || IF_ID_opcode == 5'b10000) begin
         if (IF_ID_cond == 3'd2 || IF_ID_cond == 3'd3 || IF_ID_cond == 3'd4 || IF_ID_cond == 3'd5) begin
            if ((ID_EX_ra == IF_ID_raddr1 || ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
               data_hazard = 1;
            else if ((EX_MEM_ra == IF_ID_raddr1 || EX_MEM_ra == IF_ID_rb)&& EX_MEM_WB_valid)
               data_hazard = 1;
            else if ((MEM_WB_ra == IF_ID_raddr1 || MEM_WB_ra == IF_ID_rb)&& MEM_WB_WB_valid)
               data_hazard = 1;
            else if ((WB_ra == IF_ID_raddr1 || WB_ra == IF_ID_rb) && WB_WB_valid)
                data_hazard = 1;
            else
               data_hazard = 0;
         end 

         else if (IF_ID_cond == 3'd1) begin
            if ((ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
               data_hazard = 1;
            else if ((EX_MEM_ra == IF_ID_rb)&& EX_MEM_WB_valid)
               data_hazard = 1;
            else if ((MEM_WB_ra == IF_ID_rb)&& MEM_WB_WB_valid)
               data_hazard = 1;
            else if ((WB_ra == IF_ID_rb) && WB_WB_valid)
                data_hazard = 1;
            else 
               data_hazard = 0;
         end
         else //ID_EX_cond == 3'd0
            data_hazard = 0;         
      end
      */
      //LD ->조건에 따라 R[rb] 사용
      else if (IF_ID_opcode == 5'b10011) begin
         if (IF_ID_rb == 5'b11111)
            data_hazard = 0;
            else begin
            if ((ID_EX_ra == IF_ID_rb) && ID_EX_WB_valid)
               data_hazard = 1;
            else if ((EX_MEM_ra == IF_ID_rb)&& EX_MEM_WB_valid)
               data_hazard = 1;
            else if ((MEM_WB_ra == IF_ID_rb)&& MEM_WB_WB_valid)
               data_hazard = 1;
        //    else if ((WB_ra == IF_ID_rb) && WB_WB_valid)
        //        data_hazard = 1;
            else 
               data_hazard = 0;
         end
      end
      
     //ST , STR -> 무조건 R[ra] 사용
     else if (IF_ID_opcode == 5'b10101 || IF_ID_opcode == 5'b10110) begin
      if ((ID_EX_ra == IF_ID_raddr1) && ID_EX_WB_valid)
            data_hazard = 1;
         else if ((EX_MEM_ra == IF_ID_raddr1)&& EX_MEM_WB_valid)
            data_hazard = 1;
         else if ((MEM_WB_ra == IF_ID_raddr1)&& MEM_WB_WB_valid)
            data_hazard = 1;
         //else if ((WB_ra == IF_ID_raddr1)&& WB_WB_valid)
         //   data_hazard = 1;
         else
            data_hazard = 0; 
      end
     
      //MOVI, J, JL, LDR
      else begin //R[ra] 사용X, 또는 R[ra] <= PC 또는 immediate
         data_hazard = 0;
      end
      
   end
   
   ///////////////////////////////////////////////////////////////////////
endmodule