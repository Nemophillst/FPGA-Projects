`timescale 1ns / 1ps

module double_pulse_core (
    input  wire        clk,               // 50 MHz系统时钟
    input  wire        rst_n,             // 低电平有效复位

    input  wire        dec_evt,           // 第一脉冲宽度减小
    input  wire        inc_evt,           // 第一脉冲宽度增加
    input  wire        arm_evt,           // 预使能按键事件
    input  wire        trig_evt,          // 单次触发按键事件

    output reg  [2:0]  width_level,       // 当前宽度档位：0～4
    output reg         armed,             // 预使能状态
    output wire        busy,              // 正在输出双脉冲
    output wire        pulse_out,         // 双脉冲输出
    output reg         done,              // 输出结束脉冲

    // 新增：仅供 ILA 调试使用
    output wire [1:0]  dbg_state,
    output wire [10:0] dbg_pulse1_cycles
);

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_PULSE1 = 2'd1;
    localparam [1:0] ST_GAP    = 2'd2;
    localparam [1:0] ST_PULSE2 = 2'd3;

    // 50 MHz：一个时钟周期20 ns，5 us对应250个周期
    localparam [10:0] CYC_5US = 11'd250;

    reg [1:0]  state;
    reg [10:0] counter;
    reg [10:0] pulse1_cycles;

    wire finishing_now;

    assign busy = (state != ST_IDLE);

    assign pulse_out =
        (state == ST_PULSE1) ||
        (state == ST_PULSE2);

    assign finishing_now =
        (state == ST_PULSE2) &&
        (counter == CYC_5US - 1'b1);

    /*
     * 新增：
     * 把两个核心内部信号引出去，
     * 仅用于顶层 ILA 观察。
     */
    assign dbg_state         = state;
    assign dbg_pulse1_cycles = pulse1_cycles;

    /*
     * 第一脉冲宽度档位：
     * level 0：5.04 us  = 252 × 20 ns
     * level 1：10.08 us = 504 × 20 ns
     * level 2：15.12 us = 756 × 20 ns
     * level 3：20.16 us = 1008 × 20 ns
     * level 4：25.20 us = 1260 × 20 ns
     */
    function [10:0] width_to_cycles;
        input [2:0] level;
        begin
            case (level)
                3'd0: width_to_cycles = 11'd252;
                3'd1: width_to_cycles = 11'd504;
                3'd2: width_to_cycles = 11'd756;
                3'd3: width_to_cycles = 11'd1008;
                3'd4: width_to_cycles = 11'd1260;
                default: width_to_cycles = 11'd252;
            endcase
        end
    endfunction

    /* 宽度选择与预使能控制 */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            width_level <= 3'd0;
            armed       <= 1'b0;
        end
        else begin
            if (finishing_now) begin
                armed <= 1'b0;
            end
            else if (arm_evt && !busy) begin
                armed <= ~armed;
            end

            if (!armed && !busy) begin
                if (inc_evt && width_level < 3'd4) begin
                    width_level <= width_level + 1'b1;
                end
                else if (dec_evt && width_level > 3'd0) begin
                    width_level <= width_level - 1'b1;
                end
            end
        end
    end

    /* 双脉冲状态机 */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            counter       <= 11'd0;
            pulse1_cycles <= 11'd252;
            done          <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)

                ST_IDLE: begin
                    counter <= 11'd0;

                    if (trig_evt && armed) begin
                        pulse1_cycles <= width_to_cycles(width_level);
                        state         <= ST_PULSE1;
                    end
                end

                ST_PULSE1: begin
                    if (counter == pulse1_cycles - 1'b1) begin
                        counter <= 11'd0;
                        state   <= ST_GAP;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                ST_GAP: begin
                    if (counter == CYC_5US - 1'b1) begin
                        counter <= 11'd0;
                        state   <= ST_PULSE2;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                ST_PULSE2: begin
                    if (counter == CYC_5US - 1'b1) begin
                        counter <= 11'd0;
                        state   <= ST_IDLE;
                        done    <= 1'b1;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                default: begin
                    state   <= ST_IDLE;
                    counter <= 11'd0;
                    done    <= 1'b0;
                end

            endcase
        end
    end

endmodule