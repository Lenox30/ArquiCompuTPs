`timescale 1ns / 1ps
//==============================================================================
// Testbench: UART Transmisor
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
// Descripción:
//   Testbench para verificar el transmisor UART.
//   Prueba transmisión de diferentes bytes y verifica formato de trama.
//
//==============================================================================

module uart_tx_tb;

    //==========================================================================
    // Parámetros
    //==========================================================================
    parameter CLK_PERIOD = 10;           // 100 MHz
    parameter DIVISOR = 651;             // Para generar tick 16x baud
    parameter DBIT = 8;
    parameter SB_TICK = 16;
    parameter BIT_PERIOD = CLK_PERIOD * DIVISOR * SB_TICK;  // ~104 μs
    
    //==========================================================================
    // Señales
    //==========================================================================
    reg clk, reset;
    reg tx_start;
    reg [DBIT-1:0] din;
    wire s_tick;
    wire tx;
    wire tx_done;
    
    integer test_count;
    integer passed_count;
    integer failed_count;
    
    //==========================================================================
    // Instancia del Generador de Baud Rate
    //==========================================================================
    baud_rate_generator #(
        .DIVISOR(DIVISOR)
    ) baud_gen (
        .clk(clk),
        .reset(reset),
        .tick(s_tick)
    );
    
    //==========================================================================
    // Instancia del DUT (UART TX)
    //==========================================================================
    uart_tx #(
        .DBIT(DBIT),
        .SB_TICK(SB_TICK)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .s_tick(s_tick),
        .din(din),
        .tx(tx),
        .tx_done_tick(tx_done)
    );
    
    //==========================================================================
    // Generador de Clock
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // Tarea para Transmitir un Byte
    //==========================================================================
    task send_byte;
        input [7:0] data;
        begin
            $display("\n[TEST] Transmitiendo byte: 0x%02X (%d)", data, data);
            
            @(posedge clk);
            din = data;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            
            // Esperar que termine
            wait(tx_done);
            @(posedge clk);
            
            $display("  ✅ Transmisión completada");
            test_count = test_count + 1;
            passed_count = passed_count + 1;
        end
    endtask
    
    //==========================================================================
    // Tarea para Verificar Formato de Trama
    //==========================================================================
    task verify_frame;
        input [7:0] expected_data;
        reg [7:0] received_data;
        integer i;
        begin
            $display("\n[VERIFY] Verificando trama serial...");
            
            // Verificar IDLE (debe ser 1)
            if (tx !== 1'b1) begin
                $display("  ❌ ERROR: Línea no está en IDLE (tx=%b)", tx);
                failed_count = failed_count + 1;
                disable verify_frame;
            end
            $display("  ✅ Estado IDLE correcto (tx=1)");
            
            // Iniciar transmisión
            din = expected_data;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            
            // Esperar START bit (debe cambiar a 0)
            #(BIT_PERIOD/2);  // Ir al centro del bit
            if (tx !== 1'b0) begin
                $display("  ❌ ERROR: START bit incorrecto (tx=%b, esperado=0)", tx);
                failed_count = failed_count + 1;
                disable verify_frame;
            end
            $display("  ✅ START bit correcto (tx=0)");
            
            // Leer 8 bits de datos (LSB primero)
            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD;
                received_data[i] = tx;
                $display("  Bit %0d: tx=%b", i, tx);
            end
            
            // Verificar STOP bit (debe ser 1)
            #BIT_PERIOD;
            if (tx !== 1'b1) begin
                $display("  ❌ ERROR: STOP bit incorrecto (tx=%b, esperado=1)", tx);
                failed_count = failed_count + 1;
                disable verify_frame;
            end
            $display("  ✅ STOP bit correcto (tx=1)");
            
            // Comparar datos
            if (received_data == expected_data) begin
                $display("  ✅ Datos correctos: 0x%02X", received_data);
                passed_count = passed_count + 1;
            end else begin
                $display("  ❌ ERROR: Datos incorrectos");
                $display("     Esperado: 0x%02X", expected_data);
                $display("     Recibido: 0x%02X", received_data);
                failed_count = failed_count + 1;
            end
            
            test_count = test_count + 1;
        end
    endtask
    
    //==========================================================================
    // Proceso Principal de Test
    //==========================================================================
    initial begin
        $display("==============================================================================");
        $display("  TESTBENCH: UART TRANSMISOR");
        $display("==============================================================================");
        $display("Parametros:");
        $display("  - Baud Rate: 9600 bps");
        $display("  - Bits de Datos: %0d", DBIT);
        $display("  - Oversampling: %0dx", SB_TICK);
        $display("  - Periodo de Bit: %0.2f μs", BIT_PERIOD/1000.0);
        $display("==============================================================================\n");
        
        // Inicialización
        reset = 1;
        tx_start = 0;
        din = 0;
        test_count = 0;
        passed_count = 0;
        failed_count = 0;
        
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(10) @(posedge clk);
        
        //======================================================================
        // SECCION 1: Transmisiones Básicas
        //======================================================================
        $display("\n>>> SECCION 1: TRANSMISIONES BASICAS");
        $display("=======================================================================");
        
        send_byte(8'h55);  // 0b01010101
        #(BIT_PERIOD * 2);
        
        send_byte(8'hAA);  // 0b10101010
        #(BIT_PERIOD * 2);
        
        send_byte(8'hFF);  // 0b11111111
        #(BIT_PERIOD * 2);
        
        send_byte(8'h00);  // 0b00000000
        #(BIT_PERIOD * 2);
        
        //======================================================================
        // SECCION 2: Valores de Prueba
        //======================================================================
        $display("\n>>> SECCION 2: VALORES DE PRUEBA");
        $display("=======================================================================");
        
        send_byte(8'd42);   // Decimal
        #(BIT_PERIOD * 2);
        
        send_byte(8'd127);  // Max positivo (signed)
        #(BIT_PERIOD * 2);
        
        send_byte(8'd255);  // Max unsigned
        #(BIT_PERIOD * 2);
        
        //======================================================================
        // SECCION 3: Verificación de Formato
        //======================================================================
        $display("\n>>> SECCION 3: VERIFICACION DE FORMATO DE TRAMA");
        $display("=======================================================================");
        
        verify_frame(8'hA5);
        #(BIT_PERIOD * 5);
        
        verify_frame(8'h5A);
        #(BIT_PERIOD * 5);
        
        //======================================================================
        // REPORTE FINAL
        //======================================================================
        $display("\n");
        $display("==============================================================================");
        $display("  REPORTE FINAL - UART TX TESTBENCH");
        $display("==============================================================================");
        $display("Tests ejecutados: %0d", test_count);
        $display("Tests PASADOS:    %0d", passed_count);
        $display("Tests FALLADOS:   %0d", failed_count);
        
        if (failed_count == 0) begin
            $display("\n✅ TODOS LOS TESTS PASARON");
        end else begin
            $display("\n❌ ALGUNOS TESTS FALLARON");
        end
        
        $display("==============================================================================\n");
        $finish;
    end
    
    //==========================================================================
    // Generación de Waveform
    //==========================================================================
    initial begin
        $dumpfile("uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_tb);
    end

endmodule