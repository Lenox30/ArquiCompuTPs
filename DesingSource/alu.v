`timescale 1ns / 1ps
//==============================================================================
// Trabajo Práctico 1: ALU Parametrizable
//==============================================================================
// Universidad: Universidad Nacional de Córdoba
// Facultad: FCEFyN
// Materia: Diseño de Arquitectura de Computadoras
// Año: 2025
//
// Autores:
//   - Franco Mamani
//   - Lenox Graham
//
// Fecha de Creación: [Fecha]
// Última Modificación: [Fecha]
//
// Descripción:
//   Unidad Aritmético-Lógica (ALU) parametrizable de N bits
//   Implementa 8 operaciones fundamentales y genera 3 flags
//
// Especificación:
//   - Arquitectura: Combinacional pura (sin registros internos)
//   - Operaciones: 8 (ADD, SUB, AND, OR, XOR, NOR, SRL, SRA)
//   - Flags: Zero, Overflow, Carry
//   - Parametrizable: N bits
//
// Notas de Diseño:
//   - Todas las operaciones se calculan en paralelo (arquitectura paralela)
//   - Un multiplexor selecciona el resultado según i_operacion
//   - Los flags se generan combinacionalmente a partir del resultado
//   - El camino crítico es la suma/resta (propagación de carry)
//
// Referencias:
//   - Patterson & Hennessy, "Computer Organization and Design", 5ta Ed.
//   - Hennessy & Patterson, "Computer Architecture: A Quantitative Approach"
//   - MIPS32 Architecture For Programmers, Volume II
//
// Historial de Cambios:
//   [Fecha] - v1.0 - Implementación inicial con 8 operaciones básicas
//
//==============================================================================
// 
//==============================================================================
// TABLA DE OPERACIONES
//==============================================================================
// | Operación | Código  | Función                    | Flags Afectados      |
// |-----------|---------|----------------------------|----------------------|
// | ADD       | 100000  | R = A + B (signed)         | Z, V, C              |
// | SUB       | 100010  | R = A - B (signed)         | Z, V, C              |
// | AND       | 100100  | R = A & B                  | Z                    |
// | OR        | 100101  | R = A | B                  | Z                    |
// | XOR       | 100110  | R = A ^ B                  | Z                    |
// | NOR       | 100111  | R = ~(A | B)               | Z                    |
// | SRL       | 000010  | R = A >> B[2:0] (logical)       | Z                    |
// | SRA       | 000011  | R = A >>> B[2:0] (arithmetic)   | Z                    |
//==============================================================================
// Leyenda de flags:
//   Z = Zero, V = oVerflow, C = Carry
//==============================================================================


module alu #(parameter N = 8)(    
    // Entradas de datos
    input  [N-1:0] i_datoA,
    input  [N-1:0] i_datoB,
    input  [5:0]   i_operacion,

    // Salidas de resultado
    output reg [N-1:0] o_resultado,
    
    // Flags de estado (muy importantes para el procesador)
    output o_zero,      // Resultado es cero
    output o_overflow,  // Overflow en operación con signo
    output o_carry     // Carry out de la suma/resta
    );
    
     //==========================================================================
    // SECCIÓN 1: Señales Internas y Constantes
    //==========================================================================
    // Señales auxiliares para detectar signos
    wire signo_A, signo_B, signo_resultado;
    wire overflow_add, overflow_sub;
    
    //Señales auxiliares para detectar carry
    wire [N:0] suma_extendida;
    wire carry_add;
    
    // Definición de códigos de operación
    localparam OP_ADD = 6'b100000;
    localparam OP_SUB = 6'b100010;
    localparam OP_AND = 6'b100100;
    localparam OP_OR  = 6'b100101;
    localparam OP_XOR = 6'b100110;
    localparam OP_NOR = 6'b100111;
    localparam OP_SRL = 6'b000010;
    localparam OP_SRA = 6'b000011;
     //==========================================================================
    // SECCIÓN 2: Lógica Combinacional Principal (Operaciones)
    //==========================================================================
 
    always @(*) begin
       case(i_operacion)
           OP_ADD: o_resultado = i_datoA + i_datoB;   // Suma
           OP_SUB: o_resultado = i_datoA - i_datoB;   // Resta
           OP_AND: o_resultado = i_datoA & i_datoB;   // AND
           OP_OR: o_resultado = i_datoA | i_datoB;    // OR
           OP_XOR: o_resultado = i_datoA ^ i_datoB;   // XOR
           OP_NOR: o_resultado = ~(i_datoA | i_datoB);//NOR
           OP_SRL: o_resultado = i_datoA >> i_datoB[$clog2(N)-1:0];             // SRL
           OP_SRA: o_resultado = $signed(i_datoA) >>> i_datoB[$clog2(N)-1:0];   // SRA
               default: o_resultado = {N{1'b0}};          // DEFAUL
       endcase
    end
        
     //==========================================================================
    // SECCIÓN 3: Generación de Flags
    //==========================================================================
 
 // Extracción de bits de signo
    assign signo_A = i_datoA[N-1];
    assign signo_B = i_datoB[N-1];
    assign signo_resultado = o_resultado[N-1];
    
    // Zero flag
    assign o_zero = (o_resultado == {N{1'b0}});
    
    // Overflow flag
    // Overflow en suma: signos de entrada iguales, diferente en salida
    assign overflow_add = (signo_A == signo_B) && (signo_A != signo_resultado);

    // Overflow en resta: signos de entrada diferentes, resultado diferente al operando A
    assign overflow_sub = (signo_A != signo_B) && (signo_A != signo_resultado);

    // Activar overflow solo para ADD o SUB
    assign o_overflow = ((i_operacion == OP_ADD) && overflow_add) ||
                    ((i_operacion == OP_SUB) && overflow_sub);
    
    // Carry flag
    assign suma_extendida = {1'b0, i_datoA} + {1'b0, i_datoB}; 
    // El carry es el bit extra (posición N)     
    assign carry_add = suma_extendida[N];
    // Carry solo tiene sentido en ADD
    assign o_carry = (i_operacion == OP_ADD ) ? carry_add : 1'b0;
    
endmodule
