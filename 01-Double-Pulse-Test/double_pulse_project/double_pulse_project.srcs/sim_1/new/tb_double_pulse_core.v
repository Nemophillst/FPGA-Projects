`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/18 09:45:06
// Design Name: 
// Module Name: tb_double_pulse_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
//   double_pulse_core 仿真测试平台。
//   测试第一脉冲五个档位：
//   5.04 us / 10.08 us / 15.12 us / 20.16 us / 25.20 us。
//   两脉冲间隔固定为 5.00 us，第二脉冲固定为 5.00 us。
// 
// Dependencies:
//   double_pulse_core.v
// 
// Revision:
// Revision 0.02 - 更新第一脉冲五档目标时间
// Additional Comments:
//   系统时钟为 50 MHz，时钟周期为 20 ns。
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_double_pulse_core;

    /*
     * 测试平台产生的输入
     */
    reg clk;
    reg rst_n;

    reg dec_evt;
    reg inc_evt;
    reg arm_evt;
    reg trig_evt;

    /*
     * 被测试模块的输出
     */
    wire [2:0] width_level;
    wire       armed;
    wire       busy;
    wire       pulse_out;
    wire       done;

    /*
     * 实例化被测试模块
     */
    double_pulse_core dut (
        .clk         (clk),
        .rst_n       (rst_n),

        .dec_evt     (dec_evt),
        .inc_evt     (inc_evt),
        .arm_evt     (arm_evt),
        .trig_evt    (trig_evt),

        .width_level (width_level),
        .armed       (armed),
        .busy        (busy),
        .pulse_out   (pulse_out),
        .done        (done)
    );

    /*
     * 产生 50 MHz 时钟
     *
     * 50 MHz 周期为 20 ns
     * 每 10 ns 翻转一次
     */
    initial begin
        clk = 1'b0;

        forever begin
            #10 clk = ~clk;
        end
    end

    /*
     * 模拟按一次“增加宽度”按键
     *
     * inc_evt 保持 1 个完整时钟周期
     */
    task press_inc;
        begin
            @(negedge clk);
            inc_evt = 1'b1;

            @(negedge clk);
            inc_evt = 1'b0;
        end
    endtask

    /*
     * 模拟按一次“预使能”按键
     *
     * arm_evt 保持 1 个完整时钟周期
     */
    task press_arm;
        begin
            @(negedge clk);
            arm_evt = 1'b1;

            @(negedge clk);
            arm_evt = 1'b0;
        end
    endtask

    /*
     * 模拟按一次“触发”按键
     *
     * trig_evt 保持 1 个完整时钟周期
     */
    task press_trigger;
        begin
            @(negedge clk);
            trig_evt = 1'b1;

            @(negedge clk);
            trig_evt = 1'b0;
        end
    endtask

    /*
     * 完成一次双脉冲测试：
     *
     * 1. 按一次预使能；
     * 2. 按一次触发；
     * 3. 等待双脉冲输出结束；
     * 4. 两次测试之间等待 2 us。
     */
    task fire_once;
        begin
            press_arm;
            press_trigger;

            /*
             * 等待 done 变为 1
             */
            wait(done == 1'b1);

            @(negedge clk);

            /*
             * 两次测试之间等待 2 us
             */
            #2000;
        end
    endtask

    /*
     * 以下变量用于自动测量脉冲时间
     */
    realtime first_rise_time;
    realtime first_fall_time;
    realtime second_rise_time;

    integer pulse_index;

    /*
     * 检测 pulse_out 上升沿
     */
    always @(posedge pulse_out) begin
        if (rst_n) begin

            /*
             * 第一个上升沿：
             * 第一脉冲开始
             */
            if (pulse_index == 0) begin
                first_rise_time = $realtime;
                pulse_index     = 1;
            end

            /*
             * 第二个上升沿：
             * 第二脉冲开始
             */
            else begin
                second_rise_time = $realtime;

                $display(
                    "间隔 = %0.3f us",
                    (second_rise_time -
                     first_fall_time) / 1000.0
                );

                pulse_index = 2;
            end
        end
    end

    /*
     * 检测 pulse_out 下降沿
     */
    always @(negedge pulse_out) begin
        if (rst_n) begin

            /*
             * 第一脉冲结束
             */
            if (pulse_index == 1) begin
                first_fall_time = $realtime;

                $display(
                    "第一脉冲 = %0.3f us",
                    (first_fall_time -
                     first_rise_time) / 1000.0
                );
            end

            /*
             * 第二脉冲结束
             */
            else if (pulse_index == 2) begin

                $display(
                    "第二脉冲 = %0.3f us\n",
                    ($realtime -
                     second_rise_time) / 1000.0
                );

                pulse_index = 0;
            end
        end
    end

    /*
     * 测试过程
     */
    initial begin

        /*
         * 所有输入初始化
         */
        rst_n       = 1'b0;
        dec_evt     = 1'b0;
        inc_evt     = 1'b0;
        arm_evt     = 1'b0;
        trig_evt    = 1'b0;
        pulse_index = 0;

        /*
         * 复位保持 200 ns
         */
        #200;

        rst_n = 1'b1;

        /*
         * 复位释放后等待 200 ns
         */
        #200;

        /*
         * 第一次测试：
         * 默认档位为 5.04 us
         */
        $display("开始测试 5.04 us 档位");
        fire_once;

        /*
         * 增加到 10.08 us
         */
        press_inc;

        $display("开始测试 10.08 us 档位");
        fire_once;

        /*
         * 增加到 15.12 us
         */
        press_inc;

        $display("开始测试 15.12 us 档位");
        fire_once;

        /*
         * 增加到 20.16 us
         */
        press_inc;

        $display("开始测试 20.16 us 档位");
        fire_once;

        /*
         * 增加到 25.20 us
         */
        press_inc;

        $display("开始测试 25.20 us 档位");
        fire_once;

        /*
         * 最后再等待 5 us
         */
        #5000;

        /*
         * 停止仿真
         */
        $stop;
    end

endmodule
