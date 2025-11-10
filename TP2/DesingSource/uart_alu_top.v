`timescale 1ns / 1ps
//==============================================================================
// UART ALU TOP 
//==============================================================================

module uart_alu_top #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter DATA_BITS = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire rx,
    output wire tx,
    output wire [15:0] led
);

    //==========================================================================
    // PARÁMETROS CALCULADOS
    //==========================================================================
    localparam DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
    
    //==========================================================================
    // GENERADOR DE BAUD RATE
    //==========================================================================
    wire tick;
    
    baud_rate_generator #(
        .DIVISOR(DIVISOR)
    ) baud_gen (
        .clk(clk),
        .reset(reset),
        .tick(tick)
    );
    
    //==========================================================================
    // UART RECEPTOR
    //==========================================================================
    wire rx_done;
    wire [7:0] rx_data;
    
    uart_rx #(
        .DBIT(8),
        .SB_TICK(16)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .s_tick(tick),
        .rx_done_tick(rx_done),
        .dout(rx_data)
    );
    
    //==========================================================================
    // UART TRANSMISOR
    //==========================================================================
    reg tx_start_reg;
    reg [7:0] tx_data_reg;
    wire tx_done;
    
    wire tx_internal;
    
    uart_tx #(
        .DBIT(8),
        .SB_TICK(16)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start_reg),
        .s_tick(tick),
        .din(tx_data_reg),
        .tx(tx_internal),
        .tx_done_tick(tx_done)
    );
    
    assign tx = tx_internal;
    
    //==========================================================================
    // ALU
    //==========================================================================
    reg [DATA_BITS-1:0] reg_A;
    reg [DATA_BITS-1:0] reg_B;
    reg [5:0] reg_op;
    
    wire [DATA_BITS-1:0] alu_result;
    wire alu_zero, alu_overflow, alu_carry;
    
    alu #(
        .N(DATA_BITS)
    ) alu_inst (
        .i_datoA(reg_A),
        .i_datoB(reg_B),
        .i_operacion(reg_op),
        .o_resultado(alu_result),
        .o_zero(alu_zero),
        .o_overflow(alu_overflow),
        .o_carry(alu_carry)
    );
    
    //==========================================================================
    // FSM DE CONTROL - Estados subdivididos para transmisión
    //==========================================================================
    localparam S_IDLE         = 4'd0;   // Espera primer byte
    localparam S_RECV_A       = 4'd1;   // Captura A
    localparam S_WAIT_B       = 4'd2;   // Espera segundo byte
    localparam S_RECV_B       = 4'd3;   // Captura B
    localparam S_WAIT_OP      = 4'd4;   // Espera operación
    localparam S_RECV_OP      = 4'd5;   // Captura operación
    localparam S_EXECUTE      = 4'd6;   // ALU calcula
    localparam S_SEND_RES_ST  = 4'd7;   // Envía resultado - START
    localparam S_SEND_RES_WT  = 4'd8;   // Envía resultado - WAIT
    localparam S_SEND_FLG_ST  = 4'd9;   // Envía flags - START
    localparam S_SEND_FLG_WT  = 4'd10;  // Envía flags - WAIT
    localparam S_SEND_STA_ST  = 4'd11;  // Envía status - START
    localparam S_SEND_STA_WT  = 4'd12;  // Envía status - WAIT
    
    reg [3:0] state_reg, state_next;
    
    //==========================================================================
    // FSM - REGISTRO DE ESTADO
    //==========================================================================
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= S_IDLE;
        end else begin
            state_reg <= state_next;
        end
    end
    
    //==========================================================================
    // FSM - CAPTURA DE DATOS (SECUENCIAL)
    //==========================================================================
    always @(posedge clk) begin
        if (reset) begin
            reg_A <= 0;
            reg_B <= 0;
            reg_op <= 0;
        end else begin
            case (state_reg)
                S_RECV_A:  reg_A <= rx_data;
                S_RECV_B:  reg_B <= rx_data;
                S_RECV_OP: reg_op <= rx_data[5:0];
            endcase
        end
    end
    
    //==========================================================================
    // FSM - LÓGICA DE PRÓXIMO ESTADO (COMBINACIONAL)
    //==========================================================================
    always @(*) begin
        state_next = state_reg;
        
        case (state_reg)
            S_IDLE: begin
                if (rx_done) state_next = S_RECV_A;
            end
            
            S_RECV_A: begin
                state_next = S_WAIT_B;
            end
            
            S_WAIT_B: begin
                if (rx_done) state_next = S_RECV_B;
            end
            
            S_RECV_B: begin
                state_next = S_WAIT_OP;
            end
            
            S_WAIT_OP: begin
                if (rx_done) state_next = S_RECV_OP;
            end
            
            S_RECV_OP: begin
                state_next = S_EXECUTE;
            end
            
            S_EXECUTE: begin
                state_next = S_SEND_RES_ST;
            end
            
            //==================================================================
            // ENVÍO DE RESULTADO
            //==================================================================
            S_SEND_RES_ST: begin
                state_next = S_SEND_RES_WT;
            end
            
            S_SEND_RES_WT: begin
                if (tx_done) state_next = S_SEND_FLG_ST;
            end
            
            //==================================================================
            // ENVÍO DE FLAGS
            //==================================================================
            S_SEND_FLG_ST: begin
                state_next = S_SEND_FLG_WT;
            end
            
            S_SEND_FLG_WT: begin
                if (tx_done) state_next = S_SEND_STA_ST;
            end
            
            //==================================================================
            // ENVÍO DE STATUS
            //==================================================================
            S_SEND_STA_ST: begin
                state_next = S_SEND_STA_WT;
            end
            
            S_SEND_STA_WT: begin
                if (tx_done) state_next = S_IDLE;
            end
            
            default: state_next = S_IDLE;
        endcase
    end
    
    //==========================================================================
    // GENERACIÓN DE tx_start Y tx_data (SECUENCIAL)
    //==========================================================================
    reg [3:0] state_prev;
    
    always @(posedge clk) begin
        if (reset) begin
            tx_start_reg <= 1'b0;
            tx_data_reg <= 8'h00;
            state_prev <= S_IDLE;
        end else begin
            state_prev <= state_reg;
            tx_start_reg <= 1'b0;  // Por defecto en 0
            
            // Detectar transiciones a estados _ST y generar pulso
            if ((state_prev != S_SEND_RES_ST) && (state_reg == S_SEND_RES_ST)) begin
                tx_start_reg <= 1'b1;
                tx_data_reg <= alu_result;
            end
            else if ((state_prev != S_SEND_FLG_ST) && (state_reg == S_SEND_FLG_ST)) begin
                tx_start_reg <= 1'b1;
                tx_data_reg <= {alu_zero, alu_overflow, alu_carry, 5'b00000};
            end
            else if ((state_prev != S_SEND_STA_ST) && (state_reg == S_SEND_STA_ST)) begin
                tx_start_reg <= 1'b1;
                tx_data_reg <= 8'h55;
            end
            // Mantener tx_data estable durante transmisión
            else if (state_reg == S_SEND_RES_WT) begin
                tx_data_reg <= alu_result;
            end
            else if (state_reg == S_SEND_FLG_WT) begin
                tx_data_reg <= {alu_zero, alu_overflow, alu_carry, 5'b00000};
            end
            else if (state_reg == S_SEND_STA_WT) begin
                tx_data_reg <= 8'h55;
            end
        end
    end
    
    //==========================================================================
    // ASIGNACIÓN DE LEDs PARA DEBUG
    //==========================================================================
    assign led[7:0] = alu_result;
    assign led[8] = alu_zero;
    assign led[9] = alu_overflow;
    assign led[10] = alu_carry;
    assign led[11] = (state_reg == S_RECV_A);
    assign led[12] = (state_reg == S_RECV_B);
    assign led[13] = (state_reg == S_RECV_OP);
    assign led[14] = rx_done;
    assign led[15] = tx_done_stretched;
    
endmodule