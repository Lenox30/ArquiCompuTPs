`timescale 1ns / 1ps

module uart_rx_tb;

    parameter CLK_PERIOD = 10;
    parameter DIVISOR = 651;
    parameter DBIT = 8;
    parameter SB_TICK = 16;
    parameter BIT_PERIOD = CLK_PERIOD * DIVISOR * SB_TICK;
    
    reg clk, reset, rx;
    wire s_tick, rx_done;
    wire [DBIT-1:0] dout;
    
    integer test_count, passed_count, failed_count;
    
    baud_rate_generator #(.DIVISOR(DIVISOR)) baud_gen (
        .clk(clk), .reset(reset), .tick(s_tick)
    );
    
    uart_rx #(.DBIT(DBIT), .SB_TICK(SB_TICK)) dut (
        .clk(clk), .reset(reset), .rx(rx), .s_tick(s_tick),
        .rx_done_tick(rx_done), .dout(dout)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx = 0;
            #BIT_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end
            rx = 1;
            #BIT_PERIOD;
        end
    endtask
    
    // TESTBENCH QUE SIMULA HARDWARE REAL
    task verify_reception;
        input [7:0] expected;
        reg [7:0] captured_data;
        reg captured;
        integer cycles;
        begin
            test_count = test_count + 1;
            $display("\n[TEST %0d] Enviando 0x%02X", test_count, expected);
            
            send_byte(expected);
            
            // Simular módulo receptor sincronizado
            captured = 0;
            cycles = 0;
            
            // Chequear rx_done en cada ciclo, como hardware real
            while (!captured && cycles < 500) begin
                @(posedge clk);
                
                if (rx_done) begin
                    captured_data = dout;  // Capturar dato
                    captured = 1;
                    $display("  - Dato capturado en ciclo %0d", cycles);
                end
                
                cycles = cycles + 1;
            end
            
            // Verificar
            if (!captured) begin
                $display("  ❌ FAIL: No se detectó rx_done en %0d ciclos", cycles);
                failed_count = failed_count + 1;
            end else if (captured_data != expected) begin
                $display("  ❌ FAIL: Esperado=0x%02X, Recibido=0x%02X", 
                         expected, captured_data);
                failed_count = failed_count + 1;
            end else begin
                $display("  ✅ PASS: Dato correcto (0x%02X)", captured_data);
                passed_count = passed_count + 1;
            end
            
            // Esperar entre tests
            repeat(10) @(posedge clk);
        end
    endtask
    
    initial begin
        $display("==================================================================");
        $display("  UART RX TESTBENCH - SIMULACIÓN DE HARDWARE REAL");
        $display("==================================================================\n");
        
        reset = 1;
        rx = 1;
        test_count = 0;
        passed_count = 0;
        failed_count = 0;
        
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(10) @(posedge clk);
        
        // Tests
        verify_reception(8'h55);
        verify_reception(8'hAA);
        verify_reception(8'hFF);
        verify_reception(8'h00);
        verify_reception(8'hA5);
        verify_reception(8'h5A);
        verify_reception(8'h01);
        verify_reception(8'h02);
        verify_reception(8'h03);
        
        // Reporte
        $display("\n==================================================================");
        $display("  REPORTE FINAL");
        $display("==================================================================");
        $display("Tests: %0d | Pasados: %0d | Fallados: %0d", 
                 test_count, passed_count, failed_count);
        
        if (failed_count == 0)
            $display("\n✅ TODOS LOS TESTS PASARON\n");
        else
            $display("\n❌ ALGUNOS TESTS FALLARON\n");
        
        $finish;
    end
    
    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);
    end

endmodule