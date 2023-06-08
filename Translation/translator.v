`timescale 1ns / 1ps

// This translation is enough to correctly initialize a 4Gbit x16 DDR3 module
// and do basic read/writes
module translator(
    // DDR4 input controls
    input wire         ddr4_act_n,
    input wire [16:0]  ddr4_adr,
    input wire [1:0]   ddr4_ba,
    input wire [1:0]   ddr4_bg,
    input wire         ddr4_ck_c,
    input wire         ddr4_ck_t,
    input wire         ddr4_cke,
    input wire         ddr4_cs_n,
    inout wire         ddr4_dm_n,
    inout wire [7:0]   ddr4_dq,
    inout wire         ddr4_dqs_c,
    inout wire         ddr4_dqs_t,
    input wire         ddr4_odt,
    input wire         ddr4_reset_n,

    // DDR3 output controls
    output wire         ddr3_reset_n,
    output wire         ddr3_ck_c,
    output wire         ddr3_ck_t,
    output wire         ddr3_cke,
    output wire         ddr3_cs_n,
    output reg          ddr3_ras_n,
    output reg          ddr3_cas_n,
    output reg          ddr3_we_n,
    output reg [2:0]    ddr3_ba,
    output reg [15:0]   ddr3_adr,
    inout  wire         ddr3_dqs_c,
    inout  wire         ddr3_dqs_t,
    inout  wire [7:0]   ddr3_dq,
    // DEBUG
    output wire ddr4_modeset // Active high when DDR4 controller setting Mode Registers
);
   /*
        Corresponding pins for Mode Register set
        DDR3: CS, RAS, CAS, WE low
        DDR4: CS, RAS, CAS, WE low (ACT high)
    */

    // A lot of this is 1:1 pass-through
    assign ddr3_reset_n = ddr4_reset_n;
    assign ddr3_ck_c    = ddr4_ck_c;
    assign ddr3_ck_t    = ddr4_ck_t;
    assign ddr3_cke     = ddr4_cke;
    assign ddr3_cs_n    = ddr4_cs_n;
    assign ddr3_dqs_c   = ddr4_dqs_c;
    assign ddr3_dqs_t   = ddr4_dqs_t;
    assign ddr3_dq      = ddr4_dq;

    // Debug wires
    wire ddr4_ras_n; 
    wire ddr4_cas_n; 
    wire ddr4_we_n; 

    assign ddr4_ras_n = ddr4_adr[16];
    assign ddr4_cas_n = ddr4_adr[15];
    assign ddr4_we_n  = ddr4_adr[14];
    
    assign ddr4_modeset = (ddr4_act_n & (!ddr4_ras_n) & (!ddr4_cas_n) & (!ddr4_we_n));


    // Activate translation
    // (Activate pin does NOT exist for DDR3)
    always @* begin 
        if (ddr4_act_n) begin
            ddr3_ras_n = ddr4_ras_n;
            ddr3_cas_n = ddr4_cas_n;
            ddr3_we_n  = ddr4_we_n;
        end else begin
            ddr3_ras_n = 1'b0;
            ddr3_cas_n = 1'b1;
            ddr3_we_n  = 1'b1;
        end
    end

    // Mode Register set translation
    always @* begin
        if (ddr4_modeset) begin
            case ({ddr4_bg[0], ddr4_ba[1:0]})
            3'b000: begin // Mode Register 0
                ddr3_ba[1:0] = ddr4_ba[1:0]; // MR0 - MR3
                ddr3_ba[2]   = 1'b0; // BA2 RFU
                
                // Must be set to 0, RFU
                ddr3_adr[15:13] = 3'b0;

                // Vivado has DLL for DDR4 off by default...
                ddr3_adr[12] = 1'b0; // lets default to turning this off too

                // Write recovery for auto-precharge
                // DDR3 doesn't have RTP setting, its default in silicon
                // In this case it's 4 cycles
                case ({ddr4_adr[13], ddr4_adr[11:9]}) // Max out WR at 16
                    4'b0000: ddr3_adr[11:9] = 3'b101; // WR 10 RTP 5
                    4'b0001: ddr3_adr[11:9] = 3'b110; // WR 12 RTP 6 
                    4'b0010: ddr3_adr[11:9] = 3'b111; // WR 14 RTP 7 
                    4'b0011: ddr3_adr[11:9] = 3'b000; // WR 16 RTP 8
                    4'b0100: ddr3_adr[11:9] = 3'b000; // WR 18 RTP 9 
                    4'b0101: ddr3_adr[11:9] = 3'b000; // WR 20 RTP 10
                    4'b0110: ddr3_adr[11:9] = 3'b000; // WR 24 RTP 12
                    4'b0111: ddr3_adr[11:9] = 3'b000; // WR 22 RTP 11
                    4'b1000: ddr3_adr[11:9] = 3'b000; // WR 26 RTP 13
                    default: ddr3_adr[11:9] = 3'b000;
                endcase 

                // DLL Reset (same)
                ddr3_adr[8] = ddr4_adr[8];
                ddr3_adr[8] = 1'b1;
                
                // TM (same)
                ddr3_adr[7] = ddr4_adr[7];

                // CAS latency, should we default to lowest CAS latency?, MAX 14 supported
                // Our chip only does max 10 (need to configure somehow...)
                // TURN ON STRICT TIMING LATER?
                case({ddr4_adr[12], ddr4_adr[6:4], ddr4_adr[2]})
                5'b00000: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1010; // 9
                5'b00001: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 10
                5'b00010: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 11
                5'b00011: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 12
                5'b00100: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 13
                5'b00101: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 14
                5'b00110: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 15
                5'b00111: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 16
                5'b01000: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 18
                5'b01001: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 20
                5'b01010: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 22
                5'b01011: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 24
                5'b01100: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 23
                5'b01101: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 17
                5'b01110: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 19
                5'b01111: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 21
                5'b10000: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 25 (3DS only)
                5'b10001: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 26
                5'b10010: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 27 (3DS only)
                5'b10011: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 28
                5'b10100: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // RFU 29
                5'b10101: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 30
                5'b10110: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // RFU 31
                5'b10111: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 32
                5'b11000: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // RFU
                default: {ddr3_adr[6:4], ddr3_adr[2]} = 4'b1100; // 9
                endcase

                // Read Burst type (same)
                ddr3_adr[3] = ddr4_adr[4];
                
                // Burst length (same)
                ddr3_adr[1:0] = ddr4_adr[1:0];
            
            end
            3'b001: begin // Mode Register 1
                ddr3_ba[1:0] = ddr4_ba[1:0]; // MR0 - MR3
                ddr3_ba[2]   = 1'b0; // BA2 RFU

                ddr3_adr[15:13] = 3'b0; // RFU

                // Qoff (same)
                ddr3_adr[12] = ddr4_adr[12];

                // TDQS enable (same)
                ddr3_adr[11] = ddr4_adr[11];

                ddr3_adr[10] = 1'b0; // RFU
                
                // RTT_NOM, round to closest?
                case (ddr4_adr[10:8])
                3'b000: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b000; // RTT_NOM disable 
                3'b001: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b001; // RZQ/4 
                3'b010: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b010; // RZQ/2
                3'b011: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b011; // RZQ/6
                3'b100: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b010; // RZQ/1 
                3'b101: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b011; // RZQ/5
                3'b110: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b010; // RZQ/3
                3'b111: {ddr3_adr[9], ddr3_adr[6], ddr3_adr[2]} = 3'b011; // RZQ/7
                endcase

                // Output Driver Impedence Control
                // Not the same, but just pass through right now...
                {ddr3_adr[5], ddr3_adr[1]} = ddr4_adr[2:1];
                
                // Additive latency (same)
                ddr3_adr[4:3] = ddr4_adr[4:3];

                // DLL Enable
                ddr3_adr[0] = 1'b1;
            end
            3'b010: begin // Mode Register 2
                ddr3_ba[1:0] = ddr4_ba[1:0]; // MR0 - MR3
                ddr3_ba[2]   = 1'b0; // BA2 RFU

                ddr3_adr[15:11] = 5'b0; // RFU

                // RTT_WR, round to nearest, no HI-Z supported...
                case (ddr4_adr[11:9])
                3'b000: ddr3_adr[10:9] = 2'b00; // Dynamic ODT off
                3'b001: ddr3_adr[10:9] = 2'b10; // RZQ/2
                3'b010: ddr3_adr[10:9] = 2'b01; // RZQ/1
                3'b011: ddr3_adr[10:9] = 2'b01; // HI-Z ( no termination?)
                3'b100: ddr3_adr[10:9] = 2'b01; // RZQ/3
                3'b101: ddr3_adr[10:9] = 2'b01; // RFU
                3'b110: ddr3_adr[10:9] = 2'b01; // RFU
                3'b111: ddr3_adr[10:9] = 2'b01; // RFU
                endcase

                ddr3_adr[8] = 1'b0; // RFU

                // Self-refresh temp, auto self-refresh (A7, A6)
                // No reduced temp... (default to normal)
                case (ddr4_adr[7:6]) 
                2'b00: ddr3_adr[7:6] = 2'b00; // Manual mode (normal temp)
                2'b01: ddr3_adr[7:6] = 2'b00; // Manual mode (reduced temp)
                2'b10: ddr3_adr[7:6] = 2'b10; // Manual mode (extended temp range)
                2'b11: ddr3_adr[7:6] = 2'b11; // ASR mode (self-auto refresh)
                endcase

                // CAS Write Latency (CWL)
                // probably not pass-through, change later
                ddr3_adr[5:3] = ddr4_adr[5:3];

                // Partial array self-refresh (optional so ignore)
                ddr3_adr[1:0] = 2'b0;
            end
            3'b011: begin // Mode Register 3
                ddr3_ba[1:0] = ddr4_ba[1:0]; // MR0 - MR3
                ddr3_ba[2]   = 1'b0; // BA2 RFU

                ddr3_adr[15:3] = 13'b0; // RFU

                // MPR operation
                ddr3_adr[2] = ddr4_adr[2];

                // MPR Address
                ddr3_adr[1:0] = ddr4_adr[1:0]; // Wrong but ignore
                // have to choose how to do this... or just don't support?

            end
            // Other modes, just ignore right now
            //3'b100: begin // Mode Register 4
            // Read/Write preamble
            // Read preamble training?
            // CS to CMD/ADDR latency
            // Interfal Vref, temp controlled refresh, max power down mode
            //end
            //3'b101: begin // Mode Register 5
            // Read/Write DBI
            // Data mask?
            // CA Pairty
            // CRC stuff
            //end
            //3'b110: begin // Mode Register 6
            // Vref training stuff
            //end
            //3'b111: begin // Mode Register 7 (RCW)
            //
            //end
            default: begin
                ddr3_ba[1:0] = ddr4_ba[1:0]; // MR0 - MR3
                ddr3_ba[2]   = 1'b0; // ignore...
                ddr3_adr[15:0] = ddr4_adr[15:0]; // ignore extra..
            end
            endcase
        end else begin
            ddr3_ba[1:0]   = ddr4_ba[1:0];   // MR0 - MR3
            ddr3_ba[2]     = ddr4_bg;        // Set to bank group
            ddr3_adr[15:0] = ddr4_adr[15:0]; // ignore extra right now
        end
    
    end
endmodule