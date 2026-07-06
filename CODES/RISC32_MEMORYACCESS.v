
`timescale 1ns / 1ps
`default_nettype none
`include "rv32i_header.vh"

module RISC32_MEMORYACCESS(
    input wire i_clk, i_rst_n,
    input wire[31:0] i_rs2, //data to be stored to memory is always i_rs2
    input wire[31:0] i_y, //y value from ALU (address of data to memory be stored or loaded)
    input wire[2:0] i_funct3, //funct3 from previous stage
    output reg[2:0] o_funct3, //funct3 (byte,halfword,word)
    input wire[`OPCODE_WIDTH-1:0] i_opcode, //determines if data_store will be to stored to data memory
    output reg[`OPCODE_WIDTH-1:0] o_opcode,//opcode type
    input wire[31:0] i_pc, //PC from previous stage
    output reg[31:0] o_pc, //PC value
    // Basereg Control
    input wire i_wr_rd, //write rd to base reg is enabled (from memoryaccess stage)
    output reg o_wr_rd, //write rd to the base reg if enabled
    input wire[4:0] i_rd_addr, //address for destination register (from previous stage)
    output reg[4:0] o_rd_addr, //address for destination register
    input wire[31:0] i_rd, //value to be written back to destination reg
    output reg[31:0] o_rd, //value to be written back to destination register
    // Data Memory Control
    output reg o_wb_cyc_data, //bus cycle active (1 = normal operation, 0 = all ongoing transaction are to be cancelled)
    output reg o_wb_stb_data, //request for read/write access to data memory
    output reg o_wb_we_data, //write-enable (1 = write, 0 = read)
    output reg [31:0] o_wb_addr_data, //data memory address 
    output reg[31:0] o_wb_data_data, //data to be stored to memory 
    output reg[3:0] o_wb_sel_data, //byte strobe for write (1 = write the byte) {byte3,byte2,byte1,byte0}
    input wire i_wb_ack_data, //ack by data memory (high when data to be read is ready or when write data is already written)
    input wire i_wb_stall_data, //stall by data memory (1 = data memory is busy)
    input wire[31:0] i_wb_data_data, //data retrieve from data memory 
    output reg[31:0] o_data_load, //data to be loaded to base reg (z-or-s extended) 
    /// Pipeline Control ///
    input wire i_stall_from_alu, //stalls this stage when incoming instruction is a load/store
    input wire i_ce, // input clk enable for pipeline stalling of this stage
    output reg o_ce, // output clk enable for pipeline stalling of next stage
    input wire i_stall, //informs this stage to stall
    output reg o_stall, //informs pipeline to stall
    input wire i_flush, //flush this stage
    output reg o_flush //flush previous stages
);
    
    reg[31:0] data_store_d; //data to be stored to memory
    reg[31:0] data_load_d; //data to be loaded to basereg
    reg[3:0] wr_mask_d; 
    reg pending_request; //high if there is still a pending request (request which have not yet acknowledged)
    wire[1:0] addr_2 = i_y[1:0]; //last 2  bits of data memory address
    wire stall_bit = i_stall || o_stall;

    //register the outputs of this module
    always @(posedge i_clk, negedge i_rst_n) begin
        if(!i_rst_n) begin
            o_wr_rd <= 0;
            o_wb_we_data <= 0;
            o_ce <= 0;
            o_wb_stb_data <= 0;
            pending_request <= 0;
            o_wb_cyc_data <= 0;
        end
        else begin
            // wishbone cycle will only be high if this stage is enabled
            o_wb_cyc_data <= i_ce;
            //request completed after ack
            if(i_wb_ack_data) begin 
                pending_request <= 0;
            end

            //update register only if this stage is enabled and not stalled (after load/store operation)
            if(i_ce && !stall_bit) begin 
                o_rd_addr <= i_rd_addr;
                o_funct3 <= i_funct3;
                o_opcode <= i_opcode;
                o_pc <= i_pc;
                o_wr_rd <= i_wr_rd;
                o_rd <= i_rd;
                o_data_load <= data_load_d; 
            end
            //update request to memory when no pending request yet
            if(i_ce && !pending_request) begin
                //stb goes high when instruction is a load/store and when
                //request is not already high (request lasts for 1 clk cycle
                //only)
                o_wb_stb_data <= i_opcode[`LOAD] || i_opcode[`STORE]; 
                o_wb_sel_data <= wr_mask_d;
                o_wb_we_data <= i_opcode[`STORE]; 
                pending_request <= i_opcode[`LOAD] || i_opcode[`STORE]; 
                o_wb_addr_data <= i_y; 
                o_wb_data_data <= data_store_d;
            end

            // if there is pending request but no stall from memory: idle the stb line
            if(pending_request && !i_wb_stall_data) begin
                o_wb_stb_data <= 0;
            end

            if(!i_ce) begin
                o_wb_stb_data <= 0;
            end 
            
            //flush this stage so clock-enable of next stage is disabled at next clock cycle
            if(i_flush && !stall_bit) begin 
                o_ce <= 0;
            end
            else if(!stall_bit) begin //clock-enable will change only when not stalled
                o_ce <= i_ce;
            end

            //if this stage is stalled but next stage is not, disable 
            //clock enable of next stage at next clock cycle (pipeline bubble)
            else if(stall_bit && !i_stall) o_ce <= 0;         
        end

    end 

    //determine data to be loaded to basereg or stored to data memory 
    always @* begin
        //stall while data memory has not yet acknowledged i.e.write data is not yet written or
        //read data is not yet available (no ack yet). Don't stall when need to flush by next stage
        o_stall = ((i_stall_from_alu && i_ce && !i_wb_ack_data) || i_stall) && !i_flush;         
        o_flush = i_flush; //flush this stage along with previous stages
        data_store_d = 0;
        data_load_d = 0;
        wr_mask_d = 0; 
           
        case(i_funct3[1:0]) 
            2'b00: begin //byte load/store
                    case(addr_2)  //choose which of the 4 byte will be loaded to basereg
                        2'b00: data_load_d = {24'b0, i_wb_data_data[7:0]};
                        2'b01: data_load_d = {24'b0, i_wb_data_data[15:8]};
                        2'b10: data_load_d = {24'b0, i_wb_data_data[23:16]};
                        2'b11: data_load_d = {24'b0, i_wb_data_data[31:24]};
                    endcase
                    data_load_d = {{{24{!i_funct3[2]}} & {24{data_load_d[7]}}} , data_load_d[7:0]}; //signed and unsigned extension in 1 equation
                    wr_mask_d = 4'b0001<<addr_2; //mask 1 of the 4 bytes
                    data_store_d = i_rs2<<{addr_2,3'b000}; //i_rs2<<(addr_2*8) , align data to mask
                   end
            2'b01: begin //halfword load/store
                    data_load_d = addr_2[1]? {16'b0,i_wb_data_data[31:16]}: {16'b0,i_wb_data_data[15:0]}; //choose which of the 2 halfwords will be loaded to basereg
                    data_load_d = {{{16{!i_funct3[2]}} & {16{data_load_d[15]}}},data_load_d[15:0]}; //signed and unsigned extension in 1 equation
                    wr_mask_d = 4'b0011<<{addr_2[1],1'b0}; //mask either the upper or lower half-word
                    data_store_d = i_rs2<<{addr_2[1],4'b0000}; //i_rs2<<(addr_2[1]*16) , align data to mask
                   end
            2'b10: begin //word load/store
                    data_load_d = i_wb_data_data;
                    wr_mask_d = 4'b1111; //mask all
                    data_store_d = i_rs2;
                   end
          default: begin
                    data_store_d = 0;
                    data_load_d = 0;
                    wr_mask_d = 0; 
                   end
        endcase
    end
    
`ifdef FORMAL
    always @* begin
        if(o_wb_stb_data) begin
            assert(pending_request);
        end
    end

`endif 

endmodule

