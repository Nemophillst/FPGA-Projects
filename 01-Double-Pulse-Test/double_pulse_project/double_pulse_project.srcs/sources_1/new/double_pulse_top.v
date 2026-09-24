`timescale 1ns / 1ps

module double_pulse_top (
    input  wire sys_clk,       // 50 MHz系统时钟
    input  wire sys_rst_n,     // 低电平有效复位

    input  wire key0_n,        // KEY0：减小第一脉冲宽度
    input  wire key1_n,        // KEY1：增加第一脉冲宽度
    input  wire key2_n,        // KEY2：ARM / 取消ARM
    input  wire key3_n,        // KEY3：单次触发

    output wire led0,          // ARM状态指示灯
    output wire pulse_out      // 双脉冲输出
);


    // ============================================================
    // 1. 物理按键消抖后的单周期事件
    // ============================================================

    wire key0_evt;
    wire key1_evt;
    wire key2_evt;
    wire key3_evt;


    // ============================================================
    // 2. VIO输出信号
    //
    // VIO的Output Probe会保持当前值，
    // 所以后面还要把0->1转换成单周期事件。
    // ============================================================

    wire vio_dec;
    wire vio_inc;
    wire vio_arm;
    wire vio_trig;


    // 保存VIO上一拍的状态，用于上升沿检测
    reg vio_dec_d;
    reg vio_inc_d;
    reg vio_arm_d;
    reg vio_trig_d;


    // VIO产生的单周期事件
    wire vio_dec_evt;
    wire vio_inc_evt;
    wire vio_arm_evt;
    wire vio_trig_evt;


    // ============================================================
    // 3. 最终送给double_pulse_core的事件
    //
    // 物理按键 和 VIO 两种控制方式在这里合并。
    // ============================================================

    wire dec_evt;
    wire inc_evt;
    wire arm_evt;
    wire trig_evt;


    // ============================================================
    // 4. double_pulse_core输出
    // ============================================================

    wire [2:0] width_level;
    wire       armed;
    wire       busy;
    wire       done;
    wire       pulse_out_int;


    // ============================================================
    // 5. 从core引出来给ILA看的内部调试信号
    // ============================================================

    wire [1:0]  dbg_state;
    wire [10:0] dbg_pulse1_cycles;



    // ============================================================
    // 6. 四个真实物理按键消抖
    // ============================================================

    key_debounce u_key0_debounce (
        .clk         (sys_clk),
        .rst_n       (sys_rst_n),
        .key_n       (key0_n),
        .key_pressed (),
        .press_evt   (key0_evt)
    );


    key_debounce u_key1_debounce (
        .clk         (sys_clk),
        .rst_n       (sys_rst_n),
        .key_n       (key1_n),
        .key_pressed (),
        .press_evt   (key1_evt)
    );


    key_debounce u_key2_debounce (
        .clk         (sys_clk),
        .rst_n       (sys_rst_n),
        .key_n       (key2_n),
        .key_pressed (),
        .press_evt   (key2_evt)
    );


    key_debounce u_key3_debounce (
        .clk         (sys_clk),
        .rst_n       (sys_rst_n),
        .key_n       (key3_n),
        .key_pressed (),
        .press_evt   (key3_evt)
    );



    // ============================================================
    // 7. VIO输出上升沿检测
    //
    // 例如：
    //
    // vio_arm：
    // _________|‾‾‾‾‾‾‾
    //
    // vio_arm_d：
    // ____________|‾‾‾‾
    //
    // vio_arm_evt：
    // _________|‾|______
    //
    // 产生一个50MHz时钟周期，也就是20ns的事件。
    // ============================================================

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            vio_dec_d  <= 1'b0;
            vio_inc_d  <= 1'b0;
            vio_arm_d  <= 1'b0;
            vio_trig_d <= 1'b0;
        end
        else begin
            vio_dec_d  <= vio_dec;
            vio_inc_d  <= vio_inc;
            vio_arm_d  <= vio_arm;
            vio_trig_d <= vio_trig;
        end
    end


    assign vio_dec_evt  = vio_dec  & ~vio_dec_d;
    assign vio_inc_evt  = vio_inc  & ~vio_inc_d;
    assign vio_arm_evt  = vio_arm  & ~vio_arm_d;
    assign vio_trig_evt = vio_trig & ~vio_trig_d;



    // ============================================================
    // 8. 合并真实按键和VIO
    //
    // 两个来源对double_pulse_core完全等价。
    // ============================================================

    assign dec_evt  = key0_evt | vio_dec_evt;
    assign inc_evt  = key1_evt | vio_inc_evt;
    assign arm_evt  = key2_evt | vio_arm_evt;
    assign trig_evt = key3_evt | vio_trig_evt;



    // ============================================================
    // 9. 双脉冲核心
    // ============================================================

    double_pulse_core u_double_pulse_core (
        .clk               (sys_clk),
        .rst_n             (sys_rst_n),

        .dec_evt           (dec_evt),
        .inc_evt           (inc_evt),
        .arm_evt           (arm_evt),
        .trig_evt          (trig_evt),

        .width_level       (width_level),
        .armed             (armed),
        .busy              (busy),
        .pulse_out         (pulse_out_int),
        .done              (done),

        .dbg_state         (dbg_state),
        .dbg_pulse1_cycles (dbg_pulse1_cycles)
    );



    // ============================================================
    // 10. VIO
    //
    // probe_in  ：FPGA -> VIO，用来观察
    // probe_out ：VIO  -> FPGA，用来控制
    // ============================================================

    vio_0 u_vio_0 (
        .clk        (sys_clk),

        // 观察当前状态
        .probe_in0  (width_level),
        .probe_in1  (armed),
        .probe_in2  (busy),
        .probe_in3  (done),

        // 四个虚拟按钮
        .probe_out0 (vio_dec),
        .probe_out1 (vio_inc),
        .probe_out2 (vio_arm),
        .probe_out3 (vio_trig)
    );



    // ============================================================
    // 11. ILA
    //
    // 注意：
    // 这里不再只看物理key*_evt，
    // 而是看最终送到core的dec/inc/arm/trig事件。
    //
    // 这样无论事件来自真实按钮还是VIO，
    // ILA都能看到。
    // ============================================================

    ila_0 u_ila_0 (
        .clk     (sys_clk),

        .probe0  (dbg_state),
        .probe1  (dbg_pulse1_cycles),
        .probe2  (width_level),

        .probe3  (armed),
        .probe4  (busy),
        .probe5  (done),

        .probe6  (dec_evt),
        .probe7  (inc_evt),
        .probe8  (arm_evt),
        .probe9  (trig_evt),

        .probe10 (pulse_out_int)
    );



    // ============================================================
    // 12. FPGA外部输出
    // ============================================================

    assign pulse_out = pulse_out_int;

    // armed = 1时LED显示ARM状态
    assign led0 = armed;


endmodule