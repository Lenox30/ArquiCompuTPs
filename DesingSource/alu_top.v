`timescale 1ns / 1ps
// MODO DE USO:
//   1. SW[15] = 0 → Los switches SW[7:0] se cargan en registro A
//      SW[15] = 1 → Los switches SW[7:0] se cargan en registro B
//   2. SW[13:8] = Código de operación (6 bits)
//   3. SW[7:0] = Datos de entrada (8 bits)
//   4. BTN[0] = Botón para cargar el dato (A o B según SW[15])
//
// DISTRIBUCIÓN DE LEDS:
//   LED[15:11] - Indicadores de estado
//   LED[10:8]  - Flags: [LED10=Carry, LED9=Overflow, LED8=Zero]
//   LED[7:0]   - Resultado (8 bits)
//==============================================================================

module alu_top(
    input wire clk,           // Clock de 100MHz de la Basys3
    input wire [15:0] sw,     // switches
    input wire [0:0] btn,     // BTN[0]
    output wire [15:0] led    // LEDs
);

    // Parámetro de ancho de palabra
    parameter N = 8;
    
    // Registros internos para datos A y B
    reg [N-1:0] reg_datoA;
    reg [N-1:0] reg_datoB;
    
    // Señales de control
    wire selector_AB;          // 0=A, 1=B
    wire [5:0] operacion;
    wire [N-1:0] dato_entrada;
    
    // Extracción desde switches
    assign selector_AB = sw[15];      // Switch 15: selector A/B
    assign operacion = sw[13:8];      // Switches 13-8: operación
    assign dato_entrada = sw[7:0];    // Switches 7-0: dato
    
    // Sincronización de botón (debounce simple)
    reg btn_sync1, btn_sync2, btn_prev;
    wire btn_edge;
    
    always @(posedge clk) begin
        btn_sync1 <= btn[0];
        btn_sync2 <= btn_sync1;
        btn_prev <= btn_sync2;
    end
    
    // Detectar flanco de subida del botón
    assign btn_edge = btn_sync2 & ~btn_prev;
    
    // Lógica de carga de registros
    always @(posedge clk) begin
        if (btn_edge) begin
            if (selector_AB == 1'b0) begin
                // SW[15]=0 → Cargar en A
                reg_datoA <= dato_entrada;
            end else begin
                // SW[15]=1 → Cargar en B
                reg_datoB <= dato_entrada;
            end
        end
    end
    
    // Salidas de la ALU
    wire [N-1:0] resultado;
    wire zero, overflow, carry;
    
    // Instancia de la ALU (sin flag negative)
    alu #(
        .N(N)
    ) alu_inst (
        .i_datoA(reg_datoA),
        .i_datoB(reg_datoB),
        .i_operacion(operacion),
        .o_resultado(resultado),
        .o_zero(zero),
        .o_overflow(overflow),
        .o_carry(carry)
    );
    
    // Mapeo a LEDs
    assign led[7:0] = resultado;
    
    // LED[10:8]: Flags
    assign led[8]  = zero;      // LED 8: Zero flag (Z)
    assign led[9]  = overflow;  // LED 9: Overflow flag (V)
    assign led[10] = carry;     // LED 10: Carry flag (C)
    
    // LED[15:11]: Indicadores de estado (debug)
    assign led[11] = ~selector_AB;  // LED 11: ON cuando modo A (SW15=0)
    assign led[12] = selector_AB;   // LED 12: ON cuando modo B (SW15=1)
    assign led[13] = (reg_datoA != 0); // LED 13: A tiene valor cargado
    assign led[14] = (reg_datoB != 0); // LED 14: B tiene valor cargado
    assign led[15] = 1'b1;             // LED 15: Sistema activo
    
endmodule
