`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/18 11:01:14
// Design Name: 
// Module Name: key_debounce
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module key_debounce #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,

    // 板载按键按下为低电平
    input  wire key_n,

    // 消抖后的稳定按下状态，高电平表示按下
    output reg  key_pressed,

    // 每次按下只产生一个时钟周期的事件
    output wire press_evt
);

    localparam integer COUNT_MAX =
        CLK_FREQ_HZ / 1000 * DEBOUNCE_MS;

    localparam integer COUNT_WIDTH =
        $clog2(COUNT_MAX + 1);

    reg key_sync1;
    reg key_sync2;

    reg [COUNT_WIDTH-1:0] debounce_count;
    reg stable_key;
    reg stable_key_d;

    /*
     * 两级同步
     * 同时把低有效按键转换成高有效按下信号
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync1 <= 1'b0;
            key_sync2 <= 1'b0;
        end
        else begin
            key_sync1 <= ~key_n;
            key_sync2 <= key_sync1;
        end
    end

    /*
     * 消抖处理
     * 输入连续稳定20 ms后，才更新按键状态
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_count <= {COUNT_WIDTH{1'b0}};
            stable_key     <= 1'b0;
        end
        else begin
            if (key_sync2 == stable_key) begin
                debounce_count <= {COUNT_WIDTH{1'b0}};
            end
            else begin
                if (debounce_count == COUNT_MAX - 1) begin
                    debounce_count <= {COUNT_WIDTH{1'b0}};
                    stable_key     <= key_sync2;
                end
                else begin
                    debounce_count <= debounce_count + 1'b1;
                end
            end
        end
    end

    /*
     * 边沿检测
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_key_d <= 1'b0;
            key_pressed  <= 1'b0;
        end
        else begin
            stable_key_d <= stable_key;
            key_pressed  <= stable_key;
        end
    end

    /*
     * 消抖后的按下上升沿
     */
    assign press_evt = stable_key & ~stable_key_d;

endmodule
