`timescale 1ns / 1ps
//==============================================================================
// Testbench: Baud Rate Generator
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
//   Testbench para verificar el generador de baud rate.
//   Verifica que genere ticks a la frecuencia correcta (153.6 kHz para 9600 baud)
//
//==============================================================================

module baud_rate_generator_tb;

    //==========================================================================
    // Parámetros
    //==========================================================================
    parameter CLK_PERIOD = 10;      // 100 MHz → 10 ns
    parameter DIVISOR = 651;        // Para 153.6 kHz (16x 9600 baud)
    parameter EXPECTED_TICK_PERIOD = CLK_PERIOD * DIVISOR;  // 6510 ns
    
    //==========================================================================
    // Señales
    //==========================================================================
    reg clk;
    reg reset;
    wire tick;
    
    // Contadores para verificación
    integer tick_count;
    integer cycle_count;
    real measured_period;
    integer last_tick_time;
    
    //==========================================================================
    // Instancia del DUT
    //==========================================================================
    baud_rate_generator #(
        .DIVISOR(DIVISOR)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tick(tick)
    );
    
    //==========================================================================
    // Generador de Clock (100 MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // Proceso Principal de Test
    //==========================================================================
    initial begin
        $display("==============================================================================");
        $display("  TESTBENCH: BAUD RATE GENERATOR");
        $display("==============================================================================");
        $display("Parametros:");
        $display("  - Divisor: %0d", DIVISOR);
        $display("  - Frecuencia Clock: %0d MHz", 1000/CLK_PERIOD);
        $display("  - Periodo Tick Esperado: %0d ns", EXPECTED_TICK_PERIOD);
        $display("==============================================================================\n");
        
        // Inicialización
        reset = 1;
        tick_count = 0;
        cycle_count = 0;
        last_tick_time = 0;
        
        // Esperar algunos ciclos
        repeat(5) @(posedge clk);
        reset = 0;
        
        $display("[TEST 1] Reset y Estado Inicial");
        $display("  - Reset liberado");
        
        // Esperar primer tick
        @(posedge tick);
        last_tick_time = $time;
        tick_count = tick_count + 1;
        $display("\n[TEST 2] Primer Tick Detectado");
        $display("  - Tiempo: %0t ns", $time);
        
        // Medir periodo entre varios ticks
        repeat(10) begin
            @(posedge tick);
            measured_period = $time - last_tick_time;
            last_tick_time = $time;
            tick_count = tick_count + 1;
            
            $display("[Tick %0d] Periodo medido: %0.1f ns (esperado: %0d ns)", 
                     tick_count, measured_period, EXPECTED_TICK_PERIOD);
            
            // Verificar que el periodo sea correcto
            if (measured_period != EXPECTED_TICK_PERIOD) begin
                $display("  ❌ ERROR: Periodo incorrecto!");
            end else begin
                $display("  ✅ OK");
            end
        end
        
        // Calcular frecuencia
        $display("\n==============================================================================");
        $display("  RESULTADOS FINALES");
        $display("==============================================================================");
        $display("Total de ticks generados: %0d", tick_count);
        $display("Periodo promedio: %0.1f ns", measured_period);
        $display("Frecuencia: %0.2f kHz", 1_000_000.0/measured_period);
        $display("Frecuencia esperada: %0.2f kHz", 1_000_000.0/EXPECTED_TICK_PERIOD);
        
        if (measured_period == EXPECTED_TICK_PERIOD) begin
            $display("\n✅ TEST PASSED - Baud Rate Generator funciona correctamente");
        end else begin
            $display("\n❌ TEST FAILED - Frecuencia incorrecta");
        end
        
        $display("==============================================================================\n");
        $finish;
    end
    
    //==========================================================================
    // Monitor (Opcional)
    //==========================================================================
    initial begin
        $monitor("Time=%0t | Reset=%b | Tick=%b | Counter=%0d", 
                 $time, reset, tick, dut.counter);
    end
    
    //==========================================================================
    // Generación de Waveform
    //==========================================================================
    initial begin
        $dumpfile("baud_rate_generator_tb.vcd");
        $dumpvars(0, baud_rate_generator_tb);
    end

endmodule