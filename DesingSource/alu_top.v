`timescale 1ns / 1ps
//==============================================================================
// Top Level para FPGA - ALU con Registros (8 bits)
//==============================================================================
// MODO DE USO:
//   1. SW[15] = 0 → Los switches SW[7:0] cargan en registro A
//      SW[15] = 1 → Los switches SW[7:0] cargan en registro B
//   2. SW[13:8] = Código de operación (6 bits)
//   3. SW[7:0] = Datos de entrada (8 bits)
//   4. BTN[0] = Botón para cargar el dato (A o B según SW[15])
//
// DISTRIBUCIÓN DE SWITCHES:
//   SW[15]    - Selector A/B (0=carga A, 1=carga B)
//   SW[14]    - No usado
//   SW[13:8]  - Código de operación (6 bits)
//   SW[7:0]   - Dato de entrada (8 bits)
//
// DISTRIBUCIÓN DE LEDS:
//   LED[15:11] - Indicadores de estado
//   LED[10:8]  - Flags: [LED10=Carry, LED9=Overflow, LED8=Zero]
//   LED[7:0]   - Resultado (8 bits)
//
// BOTONES:
//   BTN[0]    - Cargar dato (pulsar después de configurar switches)
//==============================================================================

module alu_top(
    input wire clk,           // Clock de 100MHz de la Basys3
    input wire [15:0] sw,     // 16 switches
    input wire [0:0] btn,     // 1 botón (solo usamos BTN[0])
    output wire [15:0] led    // 16 LEDs
);

    // Parámetro de tamaño (8 bits)
    parameter N = 8;
    
    //==========================================================================
    // Registros internos para datos A y B
    //==========================================================================
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
    
    //==========================================================================
    // Sincronización de botón (debounce simple)
    //==========================================================================
    reg btn_sync1, btn_sync2, btn_prev;
    wire btn_edge;
    
    always @(posedge clk) begin
        btn_sync1 <= btn[0];
        btn_sync2 <= btn_sync1;
        btn_prev <= btn_sync2;
    end
    
    // Detectar flanco de subida del botón
    assign btn_edge = btn_sync2 & ~btn_prev;
    
    //==========================================================================
    // Lógica de carga de registros
    //==========================================================================
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
    
    //==========================================================================
    // Salidas de la ALU
    //==========================================================================
    wire [N-1:0] resultado;
    wire zero, overflow, carry;
    
    //==========================================================================
    // Instancia de la ALU (sin flag negative)
    //==========================================================================
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
    
    //==========================================================================
    // Mapeo a LEDs
    //==========================================================================
    // LED[7:0]: Resultado de la operación
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


//==============================================================================
// GUÍA DE USO EN LA PLACA
//==============================================================================
//
// SECUENCIA PARA OPERAR:
// 
// 1. CARGAR DATO A:
//    - Poner SW[15] = OFF (abajo, posición 0)
//    - Poner el valor de A en SW[7:0]
//    - Presionar BTN[0] (centro)
//    - LED[11] debe estar encendido (modo A)
//    - LED[13] se enciende (A cargado)
//
// 2. CARGAR DATO B:
//    - Poner SW[15] = ON (arriba, posición 1)
//    - Poner el valor de B en SW[7:0]
//    - Presionar BTN[0] (centro)
//    - LED[12] debe estar encendido (modo B)
//    - LED[14] se enciende (B cargado)
//
// 3. EJECUTAR OPERACIÓN:
//    - Configurar SW[13:8] con el código de operación
//    - El resultado aparece AUTOMÁTICAMENTE en LED[7:0]
//    - Los flags aparecen en LED[10:8]
//
// EJEMPLO: CALCULAR 5 + 3
//
// Paso 1: Cargar A = 5
//   SW[15] = OFF
//   SW[7:0] = 00000101
//   Presionar BTN[0]
//
// Paso 2: Cargar B = 3
//   SW[15] = ON
//   SW[7:0] = 00000011
//   Presionar BTN[0]
//
// Paso 3: Sumar (ADD)
//   SW[13:8] = 100000 (ON ON OFF OFF OFF OFF)
//   LED[7:0] muestra 00001000 (8 en binario)
//
// CÓDIGOS DE OPERACIÓN (SW[13:8]):
//   ADD = 100000
//   SUB = 100010
//   AND = 100100
//   OR  = 100101
//   XOR = 100110
//   NOR = 100111
//   SRL = 000010
//   SRA = 000011
//
//==============================================================================