`timescale 1ns / 1ps
//==============================================================================
// Testbench Optimizado - ALU Parametrizable
// Versión 2.0 con Formato de Salida Mejorado
//==============================================================================

module alu_tb;

    //==========================================================================
    // Parámetros y Señales
    //==========================================================================
    parameter N = 8;           
    parameter NUM_RANDOM = 20; 
    
    // Señales del DUT
    reg  [N-1:0] A, B;
    reg  [5:0]   Op;
    wire [N-1:0] S;
    wire         Z, V, C;
    
    // Contadores de resultados
    integer tests_total = 0;
    integer tests_passed = 0;
    integer tests_failed = 0;
    
    // Variables para verificación
    reg [N-1:0] expected_result;
    reg expected_zero, expected_overflow, expected_carry;
    
    //==========================================================================
    // Códigos de Operación
    //==========================================================================
    localparam OP_ADD = 6'b100000;
    localparam OP_SUB = 6'b100010;
    localparam OP_AND = 6'b100100;
    localparam OP_OR  = 6'b100101;
    localparam OP_XOR = 6'b100110;
    localparam OP_NOR = 6'b100111;
    localparam OP_SRL = 6'b000010;
    localparam OP_SRA = 6'b000011;
    
    //==========================================================================
    // Instancia del DUT
    //==========================================================================
    alu #(.N(N)) dut (
        .i_datoA(A),
        .i_datoB(B),
        .i_operacion(Op),
        .o_resultado(S),
        .o_zero(Z),
        .o_overflow(V),
        .o_carry(C)
    );
    
    //==========================================================================
    // Golden Model
    //==========================================================================
    task automatic calculate_expected;
        input [N-1:0] a, b;
        input [5:0] op;
        output [N-1:0] result;
        output zero, overflow, carry;
        
        reg [N:0] extended_sum;
        reg sign_a, sign_b, sign_result;
        
        begin
            case(op)
                OP_ADD: result = a + b;
                OP_SUB: result = a - b;
                OP_AND: result = a & b;
                OP_OR:  result = a | b;
                OP_XOR: result = a ^ b;
                OP_NOR: result = ~(a | b);
                OP_SRL: result = a >> b[$clog2(N)-1:0];
                OP_SRA: result = $signed(a) >>> b[$clog2(N)-1:0];
                default: result = {N{1'b0}};
            endcase
            
            zero = (result == {N{1'b0}});
            
            sign_a = a[N-1];
            sign_b = b[N-1];
            sign_result = result[N-1];
            
            if (op == OP_ADD) begin
                overflow = (sign_a == sign_b) && (sign_a != sign_result);
            end else if (op == OP_SUB) begin
                overflow = (sign_a != sign_b) && (sign_a != sign_result);
            end else begin
                overflow = 1'b0;
            end
            
            if (op == OP_ADD) begin
                extended_sum = {1'b0, a} + {1'b0, b};
                carry = extended_sum[N];
            end else begin
                carry = 1'b0;
            end
        end
    endtask
    
    //==========================================================================
    // Tarea de Verificación MEJORADA
    //==========================================================================
    task automatic verify_operation;
        input [N-1:0] a, b;
        input [5:0] op;
        input [40*8:1] op_name; // Tamaño reducido a 40 caracteres
        
        reg test_passed;
        
        begin
            tests_total = tests_total + 1;
            
            calculate_expected(a, b, op, expected_result, expected_zero, 
                             expected_overflow, expected_carry);
            #1;
            
            test_passed = 1'b1;
            
            if (S !== expected_result) begin
                $display("[FAIL] %-30s | A=%3d B=%3d | Result=%3d (exp %3d)", 
                         op_name, $signed(a), $signed(b), $signed(S), $signed(expected_result));
                test_passed = 1'b0;
            end
            
            if (Z !== expected_zero) begin
                $display("[FAIL] %-30s | Zero flag=%b (exp %b)", op_name, Z, expected_zero);
                test_passed = 1'b0;
            end
            
            if (V !== expected_overflow) begin
                $display("[FAIL] %-30s | Overflow flag=%b (exp %b)", op_name, V, expected_overflow);
                test_passed = 1'b0;
            end
            
            if (C !== expected_carry) begin
                $display("[FAIL] %-30s | Carry flag=%b (exp %b)", op_name, C, expected_carry);
                test_passed = 1'b0;
            end
            
            if (test_passed) begin
                tests_passed = tests_passed + 1;
                $display("[PASS] %-30s | A=%3d B=%3d => Result=%3d | Z=%b V=%b C=%b", 
                         op_name, $signed(a), $signed(b), $signed(S), Z, V, C);
            end else begin
                tests_failed = tests_failed + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Proceso Principal de Testing
    //==========================================================================
    initial begin
        $display("\n");
        $display("%s", {80{"="}});
        $display("  TESTBENCH ALU PARAMETRIZABLE - %0d bits", N);
        $display("%s", {80{"="}});
        $display("Autores: Franco Mamani & Lenox Graham");
        $display("Materia: Diseno de Arquitectura de Computadoras");
        $display("Universidad Nacional de Cordoba - 2025");
        $display("%s", {80{"="}});
        $display("\n");
        
        A = 0; B = 0; Op = 0;
        #10;
        
        //======================================================================
        // SECCIÓN 1: OPERACIONES ARITMÉTICAS
        //======================================================================
        $display(">>> SECCION 1: OPERACIONES ARITMETICAS");
        $display("%s", {80{"="}});
        
        $display("\n[TEST SET] ADD (Suma)");
        A = 8'd5; B = 8'd3; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "ADD basico (5+3=8)");
        
        A = 8'd0; B = 8'd0; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "ADD cero (0+0=0)");
        
        A = 8'd255; B = 8'd1; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "ADD overflow sin signo");
        
        A = 8'd127; B = 8'd1; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "ADD overflow con signo");
        
        A = 8'd127; B = 8'd127; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "ADD overflow extremo");
        
        $display("\n[TEST SET] SUB (Resta)");
        A = 8'd10; B = 8'd3; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "SUB basico (10-3=7)");
        
        A = 8'd5; B = 8'd5; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "SUB resultado cero");
        
        A = 8'd0; B = 8'd1; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "SUB underflow");
        
        A = 8'd128; B = 8'd1; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "SUB desde negativo");
        
        //======================================================================
        // SECCIÓN 2: OPERACIONES LÓGICAS
        //======================================================================
        $display("\n>>> SECCION 2: OPERACIONES LOGICAS");
        $display("%s", {80{"="}});
        
        $display("\n[TEST SET] AND");
        A = 8'b11110000; B = 8'b10101010; Op = OP_AND; #10;
        verify_operation(A, B, Op, "AND patron");
        
        A = 8'b11111111; B = 8'b11111111; Op = OP_AND; #10;
        verify_operation(A, B, Op, "AND todo unos");
        
        A = 8'b11111111; B = 8'b00000000; Op = OP_AND; #10;
        verify_operation(A, B, Op, "AND con cero");
        
        $display("\n[TEST SET] OR");
        A = 8'b11110000; B = 8'b00001111; Op = OP_OR; #10;
        verify_operation(A, B, Op, "OR complementario");
        
        A = 8'b00000000; B = 8'b00000000; Op = OP_OR; #10;
        verify_operation(A, B, Op, "OR todo ceros");
        
        $display("\n[TEST SET] XOR");
        A = 8'b10101010; B = 8'b01010101; Op = OP_XOR; #10;
        verify_operation(A, B, Op, "XOR alternado");
        
        A = 8'b11111111; B = 8'b11111111; Op = OP_XOR; #10;
        verify_operation(A, B, Op, "XOR consigo mismo");
        
        $display("\n[TEST SET] NOR");
        A = 8'b00000000; B = 8'b00000000; Op = OP_NOR; #10;
        verify_operation(A, B, Op, "NOR de ceros");
        
        A = 8'b11111111; B = 8'b00000000; Op = OP_NOR; #10;
        verify_operation(A, B, Op, "NOR con FF");
        
        //======================================================================
        // SECCIÓN 3: DESPLAZAMIENTOS
        //======================================================================
        $display("\n>>> SECCION 3: DESPLAZAMIENTOS (SHIFTS)");
        $display("%s", {80{"="}});
        
        $display("\n[TEST SET] SRL (Shift Right Logical)");
        A = 8'b10110100; B = 8'd2; Op = OP_SRL; #10;
        verify_operation(A, B, Op, "SRL positivo");
        
        A = 8'b00000001; B = 8'd1; Op = OP_SRL; #10;
        verify_operation(A, B, Op, "SRL de 1");
        
        A = 8'b00000000; B = 8'd0; Op = OP_SRL; #10;
        verify_operation(A, B, Op, "SRL de cero");
        
        $display("\n[TEST SET] SRA (Shift Right Arithmetic)");
        A = 8'b10110100; B = 8'd2; Op = OP_SRA; #10;
        verify_operation(A, B, Op, "SRA negativo");
        
        A = 8'b01010100; B = 8'd2; Op = OP_SRA; #10;
        verify_operation(A, B, Op, "SRA positivo");
        
        A = 8'b11111111; B = 8'd0; Op = OP_SRA; #10;
        verify_operation(A, B, Op, "SRA de -1");
        
        //======================================================================
        // SECCIÓN 4: CASOS DE BORDE
        //======================================================================
        $display("\n>>> SECCION 4: CASOS DE BORDE (FLAGS)");
        $display("%s", {80{"="}});
        
        $display("\n[TEST SET] Flag ZERO");
        A = 8'd0; B = 8'd0; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Zero flag ADD");
        
        A = 8'd100; B = 8'd100; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "Zero flag SUB");
        
        A = 8'b10101010; B = 8'b01010101; Op = OP_AND; #10;
        verify_operation(A, B, Op, "Zero flag AND");
        
        $display("\n[TEST SET] Flag OVERFLOW");
        A = 8'd127; B = 8'd1; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Overflow ADD positivo");
        
        A = 8'd128; B = 8'd255; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Overflow ADD negativo");
        
        A = 8'd127; B = 8'd255; Op = OP_SUB; #10;
        verify_operation(A, B, Op, "Overflow SUB");
        
        $display("\n[TEST SET] Flag CARRY");
        A = 8'd255; B = 8'd1; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Carry suma 255+1");
        
        A = 8'd200; B = 8'd100; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Carry suma 200+100");
        
        A = 8'd128; B = 8'd127; Op = OP_ADD; #10;
        verify_operation(A, B, Op, "Carry suma 128+127");
        
        //======================================================================
        // SECCIÓN 5: CASOS ALEATORIOS
        //======================================================================
        $display("\n>>> SECCION 5: CASOS ALEATORIOS");
        $display("%s", {80{"="}});
        
        test_random_operations("ADD", OP_ADD);
        test_random_operations("SUB", OP_SUB);
        test_random_operations("AND", OP_AND);
        test_random_operations("OR",  OP_OR);
        test_random_operations("XOR", OP_XOR);
        test_random_operations("NOR", OP_NOR);
        test_random_operations("SRL", OP_SRL);
        test_random_operations("SRA", OP_SRA);
        
        //======================================================================
        // REPORTE FINAL
        //======================================================================
        $display("\n");
        $display("%s", {80{"="}});
        $display("  REPORTE FINAL DE TESTING");
        $display("%s", {80{"="}});
        $display("Tests totales ejecutados: %0d", tests_total);
        $display("Tests PASADOS:            %0d (%.2f%%)", tests_passed, 
                 (tests_passed * 100.0) / tests_total);
        $display("Tests FALLADOS:           %0d (%.2f%%)", tests_failed,
                 (tests_failed * 100.0) / tests_total);
        $display("%s", {80{"="}});
        
        if (tests_failed == 0) begin
            $display("\n TODOS LOS TESTS PASARON - ALU verificada correctamente\n");
        end else begin
            $display("\n✗ TESTS FALLADOS - Revisar implementación\n");
        end
        
        $display("Tiempo de simulación: %0t ns\n", $time);
        $finish;
    end
    
    //==========================================================================
    // Tarea para Casos Aleatorios MEJORADA
    //==========================================================================
    task automatic test_random_operations;
        input [40*8:1] op_name; // Tamaño reducido
        input [5:0] op_code;
        
        integer i, failed_this_op;
        
        begin
            failed_this_op = 0;
            $display("\n[RANDOM TEST] %s - %0d casos", op_name, NUM_RANDOM);
            
            for (i = 0; i < NUM_RANDOM; i = i + 1) begin
                A = $random;
                B = $random;
                Op = op_code;
                #10;
                
                tests_total = tests_total + 1;
                calculate_expected(A, B, Op, expected_result, expected_zero, 
                                 expected_overflow, expected_carry);
                #1;
                
                if ((S !== expected_result) || (Z !== expected_zero) || 
                    (V !== expected_overflow) || (C !== expected_carry)) begin
                    tests_failed = tests_failed + 1;
                    failed_this_op = failed_this_op + 1;
                    $display("  [FAIL] Caso #%0d: A=%0d B=%0d => S=%0d (exp %0d)",
                             i, $signed(A), $signed(B), $signed(S), $signed(expected_result));
                end else begin
                    tests_passed = tests_passed + 1;
                end
            end
            
            if (failed_this_op == 0) begin
                $display("%s: %0d/%0d casos pasaron", op_name, NUM_RANDOM, NUM_RANDOM);
            end else begin
                $display("%s: %0d/%0d casos fallaron", op_name, failed_this_op, NUM_RANDOM);
            end
        end
    endtask
    
    //==========================================================================
    // Generación de Waveforms
    //==========================================================================
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule
