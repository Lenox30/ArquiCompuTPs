`timescale 1ns / 1ps
//==============================================================================
// UART RX - VERSIÓN CORREGIDA
// Fix: rx_done_tick es un pulso de EXACTAMENTE 1 ciclo
//==============================================================================

module uart_rx #(
    parameter DBIT = 8,
    parameter SB_TICK = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire rx,
    input  wire s_tick,
    output reg  rx_done_tick,
    output reg  [DBIT-1:0] dout
);

    localparam [1:0] IDLE  = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA  = 2'b10;
    localparam [1:0] STOP  = 2'b11;
    
    reg [1:0] state_reg, state_next;
    reg [3:0] s_reg, s_next;
    reg [2:0] n_reg, n_next;
    reg [DBIT-1:0] b_reg, b_next;
    
    //==========================================================================
    // BLOQUE SECUENCIAL
    //==========================================================================
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg <= 4'd0;
            n_reg <= 3'd0;
            b_reg <= {DBIT{1'b0}};
            dout <= {DBIT{1'b0}};
            rx_done_tick <= 1'b0;
        end else begin
            // Actualizar registros de estado
            state_reg <= state_next;
            s_reg <= s_next;
            n_reg <= n_next;
            b_reg <= b_next;
            
            // CRÍTICO: rx_done_tick es un PULSO de 1 ciclo
            // Se activa SOLO cuando se cumplen TODAS las condiciones
            // Se desactiva en CUALQUIER otro caso
            rx_done_tick <= (state_reg == STOP && s_reg == 4'd15 && s_tick);
            
            // Actualizar dout cuando termina la recepción
            if (state_reg == STOP && s_reg == 4'd15 && s_tick) begin
                dout <= b_reg;
            end
        end
    end
    
    //==========================================================================
    // BLOQUE COMBINACIONAL - FSM
    //==========================================================================
    always @(*) begin
        state_next = state_reg;
        s_next = s_reg;
        n_next = n_reg;
        b_next = b_reg;
        
        case (state_reg)
            //==================================================================
            // IDLE: Esperar flanco de bajada (START bit)
            //==================================================================
            IDLE: begin
                if (~rx) begin
                    state_next = START;
                    s_next = 4'd0;
                end
            end
            
            //==================================================================
            // START: Verificar que START bit sea válido
            //==================================================================
            START: begin
                if (s_tick) begin
                    if (s_reg == 4'd7) begin
                        // Samplear en el centro del START bit
                        if (~rx) begin
                            s_next = s_reg + 4'd1;
                        end else begin
                            // Falsa detección, volver a IDLE
                            state_next = IDLE;
                        end
                    end else if (s_reg == 4'd15) begin
                        // Termina el START bit, ir a DATA
                        state_next = DATA;
                        s_next = 4'd0;
                        n_next = 3'd0;
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end
            
            //==================================================================
            // DATA: Recibir 8 bits de datos (LSB first)
            //==================================================================
            DATA: begin
                if (s_tick) begin
                    if (s_reg == 4'd7) begin
                        // Samplear en el centro del bit
                        b_next = {rx, b_reg[DBIT-1:1]};
                    end
                    
                    if (s_reg == 4'd15) begin
                        s_next = 4'd0;
                        if (n_reg == (DBIT - 1)) begin
                            // Todos los bits recibidos, ir a STOP
                            state_next = STOP;
                        end else begin
                            // Siguiente bit
                            n_next = n_reg + 3'd1;
                        end
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end
            
            //==================================================================
            // STOP: Recibir STOP bit
            //==================================================================
            STOP: begin
                if (s_tick) begin
                    if (s_reg == 4'd15) begin
                        // Termina STOP bit, volver a IDLE
                        state_next = IDLE;
                        s_next = 4'd0;
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end
            
            //==================================================================
            // DEFAULT: Estado de seguridad
            //==================================================================
            default: state_next = IDLE;
        endcase
    end
    
endmodule