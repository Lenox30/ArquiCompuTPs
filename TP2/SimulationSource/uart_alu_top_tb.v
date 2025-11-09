`timescale 1ns / 1ps
//==============================================================================
// Testbench Completo para uart_alu_top
// Diseño de Arquitectura de Computadoras - TP2
//==============================================================================
// Descripción:
//   - Verifica comunicación UART RX/TX a 9600 baudios
//   - Prueba todas las operaciones de la ALU
//   - Valida flags (Zero, Overflow, Carry)
//   - Simula casos extremos y timing crítico
//==============================================================================

module uart_alu_top_tb;

    //==========================================================================
    // PARÁMETROS DEL SISTEMA
    //==========================================================================
    parameter CLK_FREQ = 100_000_000;  // 100 MHz
    parameter BAUD_RATE = 9600;
    parameter DATA_BITS = 8;
    
    // Período de clock: 10 ns
    parameter CLK_PERIOD = 10;
    
    // Período de bit UART: 104.167 us (1/9600)
    parameter BIT_PERIOD = 1_000_000_000 / BAUD_RATE;  // en ns
    
    //==========================================================================
    // SEÑALES DEL DUT
    //==========================================================================
    reg clk;
    reg reset;
    reg rx;
    wire tx;
    wire [15:0] led;
    
    //==========================================================================
    // VARIABLES DE CONTROL DEL TESTBENCH
    //==========================================================================
    integer tests_total = 0;
    integer tests_passed = 0;
    integer tests_failed = 0;
    
    // Variables para recepción UART
    reg [7:0] received_byte;
    integer bit_index;
    
    // Variables auxiliares para tests
    reg [7:0] dummy_result, dummy_flags, dummy_status;
    
    //==========================================================================
    // INSTANCIA DEL DUT
    //==========================================================================
    uart_alu_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .led(led)
    );
    
    //==========================================================================
    // GENERADOR DE CLOCK (100 MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // TASK: ENVIAR BYTE POR UART (LSB FIRST)
    //==========================================================================
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // START bit (0)
            rx = 0;
            #BIT_PERIOD;
            
            // 8 bits de datos (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end
            
            // STOP bit (1)
            rx = 1;
            #BIT_PERIOD;
        end
    endtask
    
    //==========================================================================
    // TASK: RECIBIR BYTE POR UART (LSB FIRST)
    //==========================================================================
    task receive_uart_byte;
        output [7:0] data;
        integer i;
        begin
            // Esperar START bit (1 → 0)
            wait(tx == 0);
            #(BIT_PERIOD/2);  // Ir al centro del START bit
            
            // Leer 8 bits de datos
            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD;
                data[i] = tx;
            end
            
            // Verificar STOP bit
            #BIT_PERIOD;
            if (tx !== 1'b1) begin
                $display("[ERROR] STOP bit invalido en tiempo %0t", $time);
            end
        end
    endtask
    
    //==========================================================================
    // TASK: ENVIAR OPERACIÓN COMPLETA (A, B, OP)
    //==========================================================================
    task send_operation;
        input [7:0] operand_a;
        input [7:0] operand_b;
        input [5:0] operation;
        begin
            $display("\n[TX] Enviando: A=0x%02h, B=0x%02h, Op=0b%06b", 
                     operand_a, operand_b, operation);
            
            send_uart_byte(operand_a);
            send_uart_byte(operand_b);
            send_uart_byte({2'b00, operation});
        end
    endtask
    
    //==========================================================================
    // TASK: RECIBIR RESPUESTA COMPLETA (RESULT, FLAGS, STATUS)
    //==========================================================================
    task receive_response;
        output [7:0] result;
        output [7:0] flags;
        output [7:0] status;
        begin
            receive_uart_byte(result);
            receive_uart_byte(flags);
            receive_uart_byte(status);
            
            $display("[RX] Resultado=0x%02h, Flags=0b%08b, Status=0x%02h", 
                     result, flags, status);
        end
    endtask
    
    //==========================================================================
    // TASK: VERIFICAR OPERACIÓN COMPLETA
    //==========================================================================
    task test_operation;
        input [7:0] a;
        input [7:0] b;
        input [5:0] op;
        input [7:0] expected_result;
        input expected_zero;
        input expected_overflow;
        input expected_carry;
        input [200*8:1] test_name;  // String de hasta 200 caracteres
        
        reg [7:0] result, flags, status;
        reg flag_zero, flag_overflow, flag_carry;
        begin
            tests_total = tests_total + 1;
            
            // Enviar operación
            send_operation(a, b, op);
            
            // Recibir respuesta
            receive_response(result, flags, status);
            
            // Extraer flags individuales
            flag_zero = flags[7];
            flag_overflow = flags[6];
            flag_carry = flags[5];
            
            // Verificar resultado
            if (result === expected_result && 
                flag_zero === expected_zero &&
                flag_overflow === expected_overflow &&
                flag_carry === expected_carry &&
                status === 8'h55) begin
                
                $display("[PASS] %0s", test_name);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %0s", test_name);
                $display("       Esperado: Result=0x%02h Z=%b V=%b C=%b", 
                         expected_result, expected_zero, expected_overflow, expected_carry);
                $display("       Obtenido: Result=0x%02h Z=%b V=%b C=%b", 
                         result, flag_zero, flag_overflow, flag_carry);
                tests_failed = tests_failed + 1;
            end
        end
    endtask
    
    //==========================================================================
    // TASK: REPORTE FINAL
    //==========================================================================
    task print_final_report;
        real pass_rate;
        begin
            pass_rate = (tests_passed * 100.0) / tests_total;
            
            $display("\n");
            $display("================================================================================");
            $display("                    REPORTE FINAL - UART ALU TOP");
            $display("================================================================================");
            $display("Tests ejecutados: %0d", tests_total);
            $display("Tests PASADOS:    %0d", tests_passed);
            $display("Tests FALLADOS:   %0d", tests_failed);
            $display("Tasa de exito:    %.1f%%", pass_rate);
            $display("================================================================================");
            
            if (tests_failed == 0) begin
                $display("\n✓ TODOS LOS TESTS PASARON");
                $display("  - Comunicacion UART: OK");
                $display("  - Operaciones ALU: OK");
                $display("  - Flags: OK");
                $display("  - Protocolo: OK\n");
            end else begin
                $display("\n✗ ALGUNOS TESTS FALLARON");
                $display("  Revisar implementacion y logs anteriores\n");
            end
            
            $display("Tiempo de simulacion: %0t ns\n", $time);
        end
    endtask
    
    //==========================================================================
    // SECUENCIA DE TESTS
    //==========================================================================
    initial begin
        // Archivo VCD para GTKWave
        $dumpfile("uart_alu_top_tb.vcd");
        $dumpvars(0, uart_alu_top_tb);
        
        // Inicialización
        rx = 1;  // IDLE state de UART
        reset = 1;
        
        $display("================================================================================");
        $display("            INICIANDO TESTBENCH - UART ALU TOP");
        $display("================================================================================");
        $display("Parametros:");
        $display("  Clock:     %0d MHz", CLK_FREQ/1_000_000);
        $display("  Baud Rate: %0d", BAUD_RATE);
        $display("  Data Bits: %0d", DATA_BITS);
        $display("================================================================================\n");
        
        // Reset del sistema
        #(CLK_PERIOD * 10);
        reset = 0;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // TEST CRÍTICO: VERIFICAR BUG DE CAPTURA
        //======================================================================
        $display("\n[SUITE] TEST CRITICO - VERIFICACION DE CAPTURA CORRECTA");
        $display("================================================================================");
        $display("Este test verifica que los bytes se capturen en el orden correcto:");
        $display("  Byte 1 (0x0A) debe ir a reg_A");
        $display("  Byte 2 (0x14) debe ir a reg_B");
        $display("  Byte 3 (0x20) debe ir a reg_op");
        $display("");
        
        // Enviar secuencia conocida: A=10, B=20, Op=ADD
        send_operation(8'h0A, 8'h14, 6'b100000);
        
        // Esperar a que se capturen los datos (antes de recibir respuesta)
        #(BIT_PERIOD * 5);  // Esperar suficiente para que se capturen
        
        // Verificar que los registros tengan los valores correctos
        $display("\nEstado de registros internos:");
        $display("  reg_A  = 0x%02h (esperado: 0x0A)", dut.reg_A);
        $display("  reg_B  = 0x%02h (esperado: 0x14)", dut.reg_B);
        $display("  reg_op = 0x%02h (esperado: 0x20)", dut.reg_op);
        
        if (dut.reg_A == 8'h0A && dut.reg_B == 8'h14 && dut.reg_op == 6'h20) begin
            $display("\n[PASS] ✓ Los registros capturaron los valores correctos");
            $display("       El bug de sincronizacion fue CORREGIDO");
            tests_passed = tests_passed + 1;
        end else begin
            $display("\n[FAIL] ✗ Los registros NO tienen los valores esperados");
            $display("       POSIBLE BUG DE SINCRONIZACION");
            $display("       Ver seccion 2.6 del analisis para detalles");
            
            // Diagnóstico detallado
            if (dut.reg_A == 8'h14) begin
                $display("\n[DIAGNOSTICO] reg_A contiene el valor de B");
                $display("              Esto indica que el primer byte se perdio");
            end
            if (dut.reg_B == 8'h20) begin
                $display("[DIAGNOSTICO] reg_B contiene el valor de OP");
                $display("              Confirma el desfase de 1 byte");
            end
            
            tests_failed = tests_failed + 1;
        end
        tests_total = tests_total + 1;
        
        // Recibir la respuesta para no bloquear el sistema
        receive_response(dummy_result, dummy_flags, dummy_status);
        
        //======================================================================
        // TESTS DE OPERACIONES ARITMÉTICAS
        //======================================================================
        $display("\n[SUITE] OPERACIONES ARITMETICAS");
        $display("================================================================================");
        
        // ADD sin carry
        test_operation(8'd10, 8'd20, 6'b100000, 8'd30, 0, 0, 0,
                      "ADD: 10 + 20 = 30");
        
        // ADD con carry
        test_operation(8'd200, 8'd100, 6'b100000, 8'd44, 0, 0, 1,
                      "ADD: 200 + 100 = 44 (con carry)");
        
        // ADD resultado cero
        test_operation(8'd0, 8'd0, 6'b100000, 8'd0, 1, 0, 0,
                      "ADD: 0 + 0 = 0 (flag zero)");
        
        // ADD overflow positivo
        test_operation(8'd127, 8'd1, 6'b100000, 8'd128, 0, 1, 0,
                      "ADD: 127 + 1 = -128 (overflow)");
        
        // SUB básica - SIN carry (según especificación del TP1)
        test_operation(8'd50, 8'd30, 6'b100010, 8'd20, 0, 0, 0,
                      "SUB: 50 - 30 = 20");
        
        // SUB resultado cero - SIN carry (según especificación)
        test_operation(8'd100, 8'd100, 6'b100010, 8'd0, 1, 0, 0,
                      "SUB: 100 - 100 = 0 (flag zero)");
        
        // SUB con borrow
        test_operation(8'd10, 8'd20, 6'b100010, 8'd246, 0, 0, 0,
                      "SUB: 10 - 20 = -10 (sin signo: 246)");
        
        //======================================================================
        // TESTS DE OPERACIONES LÓGICAS
        //======================================================================
        $display("\n[SUITE] OPERACIONES LOGICAS");
        $display("================================================================================");
        
        // AND
        test_operation(8'b11110000, 8'b10101010, 6'b100100, 8'b10100000, 0, 0, 0,
                      "AND: 0xF0 & 0xAA = 0xA0");
        
        // AND resultado cero
        test_operation(8'b11110000, 8'b00001111, 6'b100100, 8'b00000000, 1, 0, 0,
                      "AND: 0xF0 & 0x0F = 0x00 (flag zero)");
        
        // OR
        test_operation(8'b11110000, 8'b00001111, 6'b100101, 8'b11111111, 0, 0, 0,
                      "OR: 0xF0 | 0x0F = 0xFF");
        
        // XOR
        test_operation(8'b11110000, 8'b10101010, 6'b100110, 8'b01011010, 0, 0, 0,
                      "XOR: 0xF0 ^ 0xAA = 0x5A");
        
        // XOR resultado cero (A XOR A = 0)
        test_operation(8'b10101010, 8'b10101010, 6'b100110, 8'b00000000, 1, 0, 0,
                      "XOR: 0xAA ^ 0xAA = 0x00 (flag zero)");
        
        // NOR
        test_operation(8'b11110000, 8'b00001111, 6'b100111, 8'b00000000, 1, 0, 0,
                      "NOR: ~(0xF0 | 0x0F) = 0x00");
        
        //======================================================================
        // TESTS DE OPERACIONES DE SHIFT
        //======================================================================
        $display("\n[SUITE] OPERACIONES DE SHIFT");
        $display("================================================================================");
        
        // SRL (Shift Right Logical)
        test_operation(8'b11110000, 8'd2, 6'b000010, 8'b00111100, 0, 0, 0,
                      "SRL: 0xF0 >> 2 = 0x3C");
        
        // SRL con carry out - SIN carry (según especificación del TP1)
        test_operation(8'b00000101, 8'd2, 6'b000010, 8'b00000001, 0, 0, 0,
                      "SRL: 0x05 >> 2 = 0x01");
        
        // SRA (Shift Right Arithmetic)
        test_operation(8'b11110000, 8'd2, 6'b000011, 8'b11111100, 0, 0, 0,
                      "SRA: 0xF0 >>> 2 = 0xFC (mantiene signo)");
        
        //======================================================================
        // TESTS DE CASOS EXTREMOS
        //======================================================================
        $display("\n[SUITE] CASOS EXTREMOS");
        $display("================================================================================");
        
        // Operandos máximos
        test_operation(8'hFF, 8'hFF, 6'b100000, 8'hFE, 0, 0, 1,
                      "ADD: 255 + 255 = 254 (con carry)");
        
        // Operandos mínimos - SIN carry en SUB
        test_operation(8'h00, 8'h00, 6'b100010, 8'h00, 1, 0, 0,
                      "SUB: 0 - 0 = 0");
        
        // Shift por 0 (no cambio)
        test_operation(8'b10101010, 8'd0, 6'b000010, 8'b10101010, 0, 0, 0,
                      "SRL: 0xAA >> 0 = 0xAA (sin cambio)");
        
        // Shift mayor que el ancho del dato (wrapping con $clog2)
        // 8 en binario es 0b1000, pero solo se usan 3 bits → 0b000 = 0
        // Por lo tanto: 0xAA >> 0 = 0xAA (sin cambio)
        test_operation(8'b10101010, 8'd8, 6'b000010, 8'b10101010, 0, 0, 0,
                      "SRL: 0xAA >> 8 = 0xAA (wrapping de 3 bits)");
        
        //======================================================================
        // TEST DE OPERACIONES CONSECUTIVAS SIN DELAY
        //======================================================================
        $display("\n[SUITE] STRESS TEST - OPERACIONES CONSECUTIVAS");
        $display("================================================================================");
        
        test_operation(8'd1, 8'd1, 6'b100000, 8'd2, 0, 0, 0,
                      "Operacion 1/5: 1+1=2");
        test_operation(8'd2, 8'd2, 6'b100000, 8'd4, 0, 0, 0,
                      "Operacion 2/5: 2+2=4");
        test_operation(8'd4, 8'd4, 6'b100000, 8'd8, 0, 0, 0,
                      "Operacion 3/5: 4+4=8");
        test_operation(8'd8, 8'd8, 6'b100000, 8'd16, 0, 0, 0,
                      "Operacion 4/5: 8+8=16");
        test_operation(8'd16, 8'd16, 6'b100000, 8'd32, 0, 0, 0,
                      "Operacion 5/5: 16+16=32");
        
        //======================================================================
        // VERIFICACIÓN DE LEDs
        //======================================================================
        $display("\n[SUITE] VERIFICACION DE LEDs");
        $display("================================================================================");
        
        // Enviar operación y verificar LEDs después
        send_operation(8'd123, 8'd45, 6'b100000);  // 123 + 45 = 168
        
        // Esperar que termine la transmisión
        #(BIT_PERIOD * 30);  // 3 bytes * 10 bits/byte
        
        // Dar tiempo para que los LEDs se actualicen
        #(CLK_PERIOD * 100);
        
        $display("Estado de LEDs:");
        $display("  LED[7:0]  (Resultado): 0x%02h (esperado: 0xA8)", led[7:0]);
        $display("  LED[8]    (Zero):      %b (esperado: 0)", led[8]);
        $display("  LED[9]    (Overflow):  %b (esperado: 1)", led[9]);
        $display("  LED[10]   (Carry):     %b (esperado: 0)", led[10]);
        
        if (led[7:0] == 8'hA8 && led[8] == 0 && led[9] == 1 && led[10] == 0) begin
            $display("[PASS] LEDs muestran valores correctos");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] LEDs no muestran valores esperados");
            tests_failed = tests_failed + 1;
        end
        tests_total = tests_total + 1;
        
        //======================================================================
        // FINALIZACIÓN
        //======================================================================
        #(BIT_PERIOD * 10);  // Esperar un poco más
        
        print_final_report();
        
        $finish;
    end
    
    //==========================================================================
    // TIMEOUT DE SEGURIDAD
    //==========================================================================
    initial begin
        #(BIT_PERIOD * 1000);  // Timeout después de ~104 ms
        $display("\n[ERROR] TIMEOUT - La simulacion tardo demasiado");
        $display("Verificar que el UART TX esta respondiendo correctamente\n");
        $finish;
    end
    
    //==========================================================================
    // MONITOR DE ESTADO PARA DEBUG
    //==========================================================================
    always @(posedge clk) begin
        // Detectar cuando se captura un dato
        if (dut.state_reg == 4'd1) begin  // S_RECV_A
            $display("[%0t] CAPTURA A: 0x%02h", $time, dut.rx_data);
        end
        if (dut.state_reg == 4'd3) begin  // S_RECV_B
            $display("[%0t] CAPTURA B: 0x%02h", $time, dut.rx_data);
        end
        if (dut.state_reg == 4'd5) begin  // S_RECV_OP
            $display("[%0t] CAPTURA OP: 0x%02h", $time, dut.rx_data);
        end
    end

endmodule