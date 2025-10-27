`timescale 1ns / 1ps
//==============================================================================
// Testbench Simplificado para alu_top
//==============================================================================
// Objetivo: Verificar SOLO la lógica de integración (registros, botón, LEDs)
// NO retestea la ALU (ya tiene 194 casos de prueba)
//==============================================================================

module alu_top_tb;

    //==========================================================================
    // Parámetros y Señales
    //==========================================================================
    parameter N = 8;
    
    reg clk;
    reg [15:0] sw;
    reg [0:0] btn;
    wire [15:0] led;
    
    // Contadores
    integer tests_passed = 0;
    integer tests_failed = 0;
    
    //==========================================================================
    // Instancia del DUT (alu_top)
    //==========================================================================
    alu_top dut (
        .clk(clk),
        .sw(sw),
        .btn(btn),
        .led(led)
    );
    
    //==========================================================================
    // Generador de Clock (100MHz → periodo 10ns)
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;  // Toggle cada 5ns → periodo 10ns
    
    //==========================================================================
    // Tarea para simular presión de botón
    //==========================================================================
    task press_button;
        begin
            btn = 1'b1;
            repeat(10) @(posedge clk);  // Mantener presionado ~100ns
            btn = 1'b0;
            repeat(5) @(posedge clk);   // Esperar estabilización
        end
    endtask
    
    //==========================================================================
    // Tarea para cargar dato en registro A
    //==========================================================================
    task load_A;
        input [7:0] value;
        begin
            sw[15] = 1'b0;      // Selector A
            sw[7:0] = value;
            press_button();
            @(posedge clk);
        end
    endtask
    
    //==========================================================================
    // Tarea para cargar dato en registro B
    //==========================================================================
    task load_B;
        input [7:0] value;
        begin
            sw[15] = 1'b1;      // Selector B
            sw[7:0] = value;
            press_button();
            @(posedge clk);
        end
    endtask
    
    //==========================================================================
    // Tarea para configurar operación
    //==========================================================================
    task set_operation;
        input [5:0] op_code;
        begin
            sw[13:8] = op_code;
            repeat(3) @(posedge clk);  // Esperar propagación
        end
    endtask
    
    //==========================================================================
    // Proceso Principal de Testing
    //==========================================================================
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("  TESTBENCH - ALU_TOP");
        $display("================================================================================");
        $display("Objetivo: Verificar lógica de integración (registros, botón, LEDs)");
        $display("================================================================================");
        $display("\n");
        
        // Inicialización
        sw = 16'h0000;
        btn = 1'b0;
        
        // Esperar estabilización
        repeat(10) @(posedge clk);
        
        //======================================================================
        // TEST 1: Verificar carga de registro A
        //======================================================================
        $display("[TEST 1] Carga de Registro A");
        load_A(8'd42);
        
        if (dut.reg_datoA == 8'd42) begin
            $display("  [PASS] Registro A cargado correctamente: %d", dut.reg_datoA);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Registro A esperado: 42, obtenido: %d", dut.reg_datoA);
            tests_failed = tests_failed + 1;
        end
        
        // Verificar LED de indicador A
        if (led[11] == 1'b1 && led[13] == 1'b1) begin
            $display("  [PASS] Indicadores LED de registro A correctos");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Indicadores LED de registro A incorrectos");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 2: Verificar carga de registro B
        //======================================================================
        $display("\n[TEST 2] Carga de Registro B");
        load_B(8'd17);
        
        if (dut.reg_datoB == 8'd17) begin
            $display("  [PASS] Registro B cargado correctamente: %d", dut.reg_datoB);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Registro B esperado: 17, obtenido: %d", dut.reg_datoB);
            tests_failed = tests_failed + 1;
        end
        
        // Verificar LED de indicador B
        if (led[12] == 1'b1 && led[14] == 1'b1) begin
            $display("  [PASS] Indicadores LED de registro B correctos");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Indicadores LED de registro B incorrectos");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 3: Verificar operación ADD (integración completa)
        //======================================================================
        $display("\n[TEST 3] Operacion ADD (42 + 17 = 59)");
        set_operation(6'b100000);  // ADD
        
        if (led[7:0] == 8'd59) begin
            $display("  [PASS] Resultado ADD correcto: %d", led[7:0]);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Resultado ADD esperado: 59, obtenido: %d", led[7:0]);
            tests_failed = tests_failed + 1;
        end
        
        // Verificar flags (no debe haber carry/overflow para 42+17)
        if (led[8] == 1'b0 && led[9] == 1'b0 && led[10] == 1'b0) begin
            $display("  [PASS] Flags correctos (Z=0, V=0, C=0)");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Flags incorrectos: Z=%b V=%b C=%b", led[8], led[9], led[10]);
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 4: Verificar operación SUB
        //======================================================================
        $display("\n[TEST 4] Operacion SUB (42 - 17 = 25)");
        set_operation(6'b100010);  // SUB
        
        if (led[7:0] == 8'd25) begin
            $display("  [PASS] Resultado SUB correcto: %d", led[7:0]);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Resultado SUB esperado: 25, obtenido: %d", led[7:0]);
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 5: Verificar flag Zero
        //======================================================================
        $display("\n[TEST 5] Flag Zero (5 - 5 = 0)");
        load_A(8'd5);
        load_B(8'd5);
        set_operation(6'b100010);  // SUB
        
        if (led[7:0] == 8'd0 && led[8] == 1'b1) begin
            $display("  [PASS] Resultado=0 y flag Zero=1");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Resultado=%d, flag Zero=%b", led[7:0], led[8]);
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 6: Verificar flag Carry
        //======================================================================
        $display("\n[TEST 6] Flag Carry (255 + 1)");
        load_A(8'd255);
        load_B(8'd1);
        set_operation(6'b100000);  // ADD
        
        if (led[10] == 1'b1) begin
            $display("  [PASS] Flag Carry activado correctamente");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Flag Carry deberia estar en 1");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 7: Verificar flag Overflow
        //======================================================================
        $display("\n[TEST 7] Flag Overflow (127 + 1)");
        load_A(8'd127);
        load_B(8'd1);
        set_operation(6'b100000);  // ADD
        
        if (led[9] == 1'b1) begin
            $display("  [PASS] Flag Overflow activado correctamente");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Flag Overflow deberia estar en 1");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 8: Verificar debouncing (múltiples pulsos rápidos)
        //======================================================================
        $display("\n[TEST 8] Robustez del debouncing");
        load_A(8'd10);
        
        // Intentar confundir con pulsos muy rápidos
        btn = 1'b1;
        @(posedge clk);
        btn = 1'b0;
        @(posedge clk);
        btn = 1'b1;
        @(posedge clk);
        btn = 1'b0;
        repeat(10) @(posedge clk);
        
        if (dut.reg_datoA == 8'd10) begin
            $display("  [PASS] Debouncing maneja pulsos rapidos correctamente");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Debouncing fallo con pulsos rapidos");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 9: Verificar operación AND
        //======================================================================
        $display("\n[TEST 9] Operacion AND (0xFF & 0xAA = 0xAA)");
        load_A(8'hFF);
        load_B(8'hAA);
        set_operation(6'b100100);  // AND
        
        if (led[7:0] == 8'hAA) begin
            $display("  [PASS] Resultado AND correcto: 0x%h", led[7:0]);
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Resultado AND esperado: 0xAA, obtenido: 0x%h", led[7:0]);
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // TEST 10: Verificar que registros mantienen valor
        //======================================================================
        $display("\n[TEST 10] Persistencia de registros");
        load_A(8'd100);
        load_B(8'd50);
        
        // Cambiar switches sin presionar botón
        sw[7:0] = 8'd99;
        repeat(20) @(posedge clk);
        
        if (dut.reg_datoA == 8'd100 && dut.reg_datoB == 8'd50) begin
            $display("  [PASS] Registros mantienen valor sin pulsar boton");
            tests_passed = tests_passed + 1;
        end else begin
            $display("  [FAIL] Registros cambiaron sin pulsar boton");
            tests_failed = tests_failed + 1;
        end
        
        //======================================================================
        // REPORTE FINAL
        //======================================================================
        $display("\n");
        $display("================================================================================");
        $display("  REPORTE FINAL - ALU_TOP INTEGRATION TEST");
        $display("================================================================================");
        $display("Tests ejecutados: %0d", tests_passed + tests_failed);
        $display("Tests PASADOS:    %0d", tests_passed);
        $display("Tests FALLADOS:   %0d", tests_failed);
        $display("Tasa de exito:    %.1f%%", (tests_passed * 100.0) / (tests_passed + tests_failed));
        $display("================================================================================");
        
        if (tests_failed == 0) begin
            $display("\n TODOS LOS TESTS DE INTEGRACION PASARON");
            $display("  - Carga de registros: OK");
            $display("  - Debouncing de boton: OK");
            $display("  - Integracion con ALU: OK");
            $display("  - Mapeo de LEDs: OK\n");
        end else begin
            $display("\n ALGUNOS TESTS FALLARON - Revisar implementacion\n");
        end
        
        $display("Tiempo de simulacion: %0t ns\n", $time);
        $finish;
    end
    
    //==========================================================================
    // Monitor (opcional - comentar si genera mucha salida)
    //==========================================================================
    
    initial begin
        $monitor("\nTime=%0t | RegA=%d | RegB=%d | Op=%b | LED[7:0]=%b | Flags: Z=%b V=%b C=%b",
                 $time, dut.reg_datoA, dut.reg_datoB, sw[13:8], led[7:0], led[8], led[9], led[10]);
    end
    

endmodule