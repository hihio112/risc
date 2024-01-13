/*
    ASYNCHRONOUS READ SYNCHRONOUS WRITE REGISTER FILE MODEL
   
    FUNCTION TABLE:

    CLK        WEN        WA        DI        COMMENT
    ===================================================
    posedge    H          X         X         WRITE STANDBY
    posedge    L          VALID     VALID     WRITE
 
    CLK        RA                   DOUT      COMMENT
    ===================================================
    X          VALID                MEM(RA)   READ

    USAGE:
    REGFILE    #(.AW(5), .ENTRY(32))    RegFile (
                    .CLK    (CLK),
                    .RSTN    (RSTN),
                    .WEN    (),
                    .WA     (),
                    .DI     (),
                    .RA0    (),
                    .RA1    (),
                    .DOUT0  (),
                    .DOUT1  ()
    );
*/

module REGFILE #(parameter AW = 5, ENTRY = 32) (
    input    wire                CLK, 
    input    wire                RSTN,	 // RESET (ACTIVE LOW)

    // WRITE PORT
    input    wire                WEN,    // WRITE ENABLE (ACTIVE LOW)
    input    wire    [AW-1:0]    WA,     // WRITE ADDRESS
    input    wire    [31:0]      DI,     // DATA INPUT

    // READ PORT
    input    wire    [AW-1:0]    RA0,    // READ ADDRESS 0
    input    wire    [AW-1:0]    RA1,    // READ ADDRESS 1
    output   wire    [31:0]      DOUT0,  // DATA OUTPUT 0
    output   wire    [31:0]      DOUT1   // DATA OUTPUT 1
);

    parameter    ATIME    = 1;			//READ DELAY

    reg        [31:0]        ram[0:ENTRY-1];

    always @ (posedge CLK or negedge RSTN)
    begin
        if(~RSTN)
        begin
            ram[0] <= 32'b0; ram[1] <= 32'b0; ram[2] <= 32'b0; ram[3] <= 32'b0;
            ram[4] <= 32'b0; ram[5] <= 32'b0; ram[6] <= 32'b0; ram[7] <= 32'b0;
            ram[8] <= 32'b0; ram[9] <= 32'b0; ram[10] <= 32'b0; ram[11] <= 32'b0;
            ram[12] <= 32'b0; ram[13] <= 32'b0; ram[14] <= 32'b0; ram[15] <= 32'b0;
            ram[16] <= 32'b0; ram[17] <= 32'b0; ram[18] <= 32'b0; ram[19] <= 32'b0;
            ram[20] <= 32'b0; ram[21] <= 32'b0; ram[22] <= 32'b0; ram[23] <= 32'b0;
            ram[24] <= 32'b0; ram[25] <= 32'b0; ram[26] <= 32'b0; ram[27] <= 32'b0;
            ram[28] <= 32'b0; ram[29] <= 32'b0; ram[30] <= 32'b0; ram[31] <= 32'b0;
        end
        else
        begin
            if (~WEN)    ram[WA] <= DI;		//SYNCHRONOUS WRITE WITH NO DELAY
        end
    end

    assign    #(ATIME)    DOUT0    = ram[RA0];
    assign    #(ATIME)    DOUT1    = ram[RA1];

endmodule




/*
    SINGLE-PORT SYNCHRONOUS MEMORY MODEL

    FUNCTION TABLE:

    CLK        CSN      WEN      A        DI       DOUT        COMMENT
    ======================================================================
    posedge    H        X        X        X        DOUT(t-1)   DESELECTED
    posedge    L        L        VALID    VALID    DOUT(t-1)   WRITE CYCLE
    posedge    L        H        VALID    X        MEM(A)      READ CYCLE

    USAGE:

    SRAM    #(.BW(32), .AW(10), .ENTRY(1024)) InstMemory (
                    .CLK    (CLK),
                    .CSN    (1'b0),
                    .A      (),
                    .WEN    (),
                    .DI     (),
                    .DOUT   ()
    );
*/

module SRAM #(parameter BW = 32, AW = 10, ENTRY = 1024, WRITE = 0, MEM_FILE="mem.hex") (
    input    wire                CLK,
    input    wire                CSN,    // CHIP SELECT (ACTIVE LOW)
    input    wire    [AW-1:0]    A,      // ADDRESS
    input    wire                WEN,    // READ/WRITE ENABLE
    input    wire    [BW-1:0]    DI,     // DATA INPUT
    output   wire    [BW-1:0]    DOUT    // DATA OUTPUT
);

    parameter    ATIME    = 2;

    reg        [BW-1:0]    ram[0:ENTRY-1];
    reg        [BW-1:0]    outline;

    initial begin
	    if(WRITE>0)
		    $readmemh(MEM_FILE, ram);
    end

    always @ (posedge CLK)
    begin
        if (~CSN)
        begin
            if (WEN)    outline    <= ram[A];
            else        ram[A]    <= DI;
        end
    end

    assign    #(ATIME)    DOUT    = outline;

endmodule
