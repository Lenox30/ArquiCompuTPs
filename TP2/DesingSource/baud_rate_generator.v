`timescale 1ns / 1ps
//==============================================================================
// UART BAUD RATE
//==============================================================================

module baud_rate_generator #(
    parameter DIVISOR = 651 // Divisor = 
)(
    input  wire clk,
    input  wire reset,
    output wire tick
);
    localparam COUNTER_WIDTH = $clog2(DIVISOR);
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end
    
    assign tick = (counter == DIVISOR - 1);
    
endmodule
