`timescale 1ns / 1ps

//==============================================================================
// UART TX
//==============================================================================


module uart_tx #(
    parameter DBIT = 8,      // Bits de datos
    parameter SB_TICK = 16   // Ticks por bit (para llegar a los 9600Hz)
)(
    input  wire clk,
    input  wire reset,
    input  wire tx_start,         // Señal para iniciar transmisión
    input  wire s_tick,           // Tick del baud rate generator
    input  wire [DBIT-1:0] din,   // Datos a transmitir
    output wire  tx,               // Línea serial TX
    output wire tx_done_tick      // Pulso cuando termina transmisión
);

    // Estados de la FSM
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] state_reg, state_next;  // Estados
    reg [3:0] s_reg, s_next;          // Contador de ticks de sampling
    reg [2:0] n_reg, n_next;          // Contador de bits transmitidos
    reg [DBIT-1:0] b_reg, b_next;     // Buffer de datos
    reg tx_reg, tx_next;              // Tx
    
    // Registros de estado
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg <= 0;
            n_reg <= 0;
            b_reg <= 0;
            tx_reg <= 1'b1;  // IDLE es '1'
        end else begin
            state_reg <= state_next;
            s_reg <= s_next;
            n_reg <= n_next;
            b_reg <= b_next;
            tx_reg <= tx_next;
        end
    end
    
    // Lógica de próximo estado y salida
    always @(*) begin
        state_next = state_reg;
        s_next = s_reg;
        n_next = n_reg;
        b_next = b_reg;
        tx_next = tx_reg;
        
        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;  // Línea en IDLE
                if (tx_start) begin
                    state_next = START;
                    s_next = 0;
                    b_next = din;  // Cargar datos a transmitir
                end
            end
            
            START: begin
                tx_next = 1'b0;  // Bit de START
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin  // Esperamos 
                        state_next = DATA;
                        s_next = 0;
                        n_next = 0;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            
            DATA: begin
                tx_next = b_reg[0];  // Transmitir LSB primero
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin // Esperamos
                        s_next = 0;
                        b_next = {1'b0, b_reg[DBIT-1:1]};  // Shift derecha para transmitir b_reg[0]
                        if (n_reg == DBIT - 1) begin
                            state_next = STOP;
                        end else begin
                            n_next = n_reg + 1;
                        end
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            
            STOP: begin
                tx_next = 1'b1;  // Bit de STOP 
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin
                        state_next = IDLE;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
        endcase
    end
    
    assign tx = tx_reg;
    assign tx_done_tick = (state_reg == STOP) && (s_reg == SB_TICK - 1) && s_tick;
    
endmodule
