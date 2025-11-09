`timescale 1ns / 1ps
//==============================================================================
// UART ALU TOP
// FSM de 9 estados
//==============================================================================
// Flujo:
//   1. IDLE: espera byte A
//   2. RECV_A: captura A (dato ya está estable en rx_data)
//   3. WAIT_B: espera byte B
//   4. RECV_B: captura B
//   5. WAIT_OP: espera operación
//   6. RECV_OP: captura operación
//   7. EXECUTE: ALU calcula
//   8-10. SEND_RES, SEND_FLG, SEND_STA: envía respuesta
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
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_done;
    
    uart_tx #(
        .DBIT(8),
        .SB_TICK(16)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .s_tick(tick),
        .din(tx_data),
        .tx(tx),
        .tx_done_tick(tx_done)
    );
    
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
    // FSM DE CONTROL - 9 ESTADOS
    //==========================================================================
    localparam S_IDLE     = 4'd0;   // Espera primer byte
    localparam S_RECV_A   = 4'd1;   // Captura A
    localparam S_WAIT_B   = 4'd2;   // Espera segundo byte
    localparam S_RECV_B   = 4'd3;   // Captura B
    localparam S_WAIT_OP  = 4'd4;   // Espera operación
    localparam S_RECV_OP  = 4'd5;   // Captura operación
    localparam S_EXECUTE  = 4'd6;   // ALU calcula
    localparam S_SEND_RES = 4'd7;   // Envía resultado
    localparam S_SEND_FLG = 4'd8;   // Envía flags
    localparam S_SEND_STA = 4'd9;   // Envía status
    
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
            tx_data = 0;
        end else begin
            // Capturar en los estados específicos de captura
            case (state_reg)
                S_RECV_A: reg_A <= rx_data;
                S_RECV_B: reg_B <= rx_data;
                S_RECV_OP: reg_op <= rx_data[5:0];
            endcase
        end
    end
    
    //==========================================================================
    // FSM - LÓGICA DE PRÓXIMO ESTADO Y SALIDAS (COMBINACIONAL)
    //==========================================================================
    always @(*) begin
        // Valores por defecto
        state_next = state_reg;
        tx_start = 1'b0;
        tx_data = 8'h00;
        
        case (state_reg)
            //==================================================================
            // IDLE: Esperar primer byte (operando A)
            //==================================================================
            S_IDLE: begin
                if (rx_done) begin
                    state_next = S_RECV_A;
                    
                end
            end
            
            //==================================================================
            // RECV_A: Capturar operando A (dato ya está en rx_data)
            //==================================================================
            S_RECV_A: begin
                // Captura automática en el bloque secuencial
                // Transición inmediata (sin esperar rx_done)
                state_next = S_WAIT_B;
            end
            
            //==================================================================
            // WAIT_B: Esperar segundo byte (operando B)
            //==================================================================
            S_WAIT_B: begin
                if (rx_done) begin
                    state_next = S_RECV_B;
                end
            end
            
            //==================================================================
            // RECV_B: Capturar operando B
            //==================================================================
            S_RECV_B: begin
                // Captura automática en el bloque secuencial
                state_next = S_WAIT_OP;
            end
            
            //==================================================================
            // WAIT_OP: Esperar tercer byte (operación)
            //==================================================================
            S_WAIT_OP: begin
                if (rx_done) begin
                    state_next = S_RECV_OP;
                end
            end
            
            //==================================================================
            // RECV_OP: Capturar operación
            //==================================================================
            S_RECV_OP: begin
                // Captura automática en el bloque secuencial
                state_next = S_EXECUTE;
            end
            
            //==================================================================
            // EXECUTE: ALU procesa (1 ciclo)
            //==================================================================
            S_EXECUTE: begin
                // La ALU es combinacional, resultado listo inmediatamente
                state_next = S_SEND_RES;
            end
            
            //==================================================================
            // SEND_RES: Enviar byte de resultado
            //==================================================================
            S_SEND_RES: begin
                tx_start = 1'b1;
                tx_data = alu_result;
                
                if (tx_done) begin
                    state_next = S_SEND_FLG;
                end
            end
            
            //==================================================================
            // SEND_FLG: Enviar byte de flags
            //==================================================================
            S_SEND_FLG: begin
                tx_start = 1'b1;
                tx_data = {alu_zero, alu_overflow, alu_carry, 5'b00000};
                
                if (tx_done) begin
                    state_next = S_SEND_STA;
                end
            end
            
            //==================================================================
            // SEND_STA: Enviar byte de status y volver a IDLE
            //==================================================================
            S_SEND_STA: begin
                tx_start = 1'b1;
                tx_data = 8'h55;  // Status: OK
                
                if (tx_done) begin
                    state_next = S_IDLE;
                end
            end
            
            //==================================================================
            // DEFAULT: Volver a IDLE (estado de seguridad)
            //==================================================================
            default: begin
                state_next = S_IDLE;
            end
        endcase
    end
    
    //==========================================================================
    // ASIGNACIÓN DE LEDs PARA DEBUG
    //==========================================================================
    assign led[7:0] = alu_result;           // LEDs 0-7: Resultado
    assign led[8] = alu_zero;               // LED 8: Zero flag
    assign led[9] = alu_overflow;           // LED 9: Overflow flag
    assign led[10] = alu_carry;             // LED 10: Carry flag
    assign led[11] = (state_reg == S_RECV_A);  // LED 11: Debug - Capturando A
    assign led[12] = (state_reg == S_RECV_B);  // LED 12: Debug - Capturando B
    assign led[13] = (state_reg == S_RECV_OP); // LED 13: Debug - Capturando OP
    assign led[14] = rx_done;               // LED 14: RX activo
    assign led[15] = tx_done;               // LED 15: TX activo
    
endmodule