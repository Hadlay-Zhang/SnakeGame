`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/22 01:57:01
// Design Name: 张智淋 2054169
// Module Name: snake
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

module snake(
    input clk,
    input UP,
    input DOWN,
    input LEFT,
    input RIGHT,
    input in_rst,
    input switch_J15,
    input switch_M13,
    input rx,//蓝牙串口接收数据
    output O_hs,
	output O_vs,
    output po_flag,//蓝牙串行转并行数据有效信号
    output [4:0] move_state,
    output [1:0] general_state,
    output flag_isdead,
    output [3:0] O_red,// VGA红色分量
    output [3:0] O_green,// VGA绿色分量
    output [3:0] O_blue// VGA蓝色分量
);
reg clk_50M;
reg clk_25M;
parameter LENGTH_MAX = 20;
wire [1:0] difficulty_state;
wire rst_n;
wire UP_ns;
wire DOWN_ns;
wire LEFT_ns;
wire RIGHT_ns;
wire UP_bluetooth;//蓝牙传输的键
wire DOWN_bluetooth;//蓝牙传输的键
wire LEFT_bluetooth;//蓝牙传输的键
wire RIGHT_bluetooth;//蓝牙传输的键
wire [4:0] random_x;
wire [4:0] random_y;
wire [LENGTH_MAX * 10 - 1:0] snake_x;
wire [LENGTH_MAX * 10 - 1:0] snake_y;
wire [9:0] snake_length;
wire [7:0] po_data;//蓝牙读取的有效数据
//分频25M
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        clk_50M   <=  1'b0        ;
    else
        clk_50M   <=  ~clk_50M  ;     
end

always @(posedge clk_50M or negedge rst_n)
begin
    if(!rst_n)
        clk_25M   <=  1'b0        ;
    else
        clk_25M   <=  ~clk_25M  ;     
end

reset reset_inst(
    .in_rst(in_rst),
    .rst_n(rst_n)
);

key_filter key_filter_left(
    .clk(clk_25M),
    .rst_n(rst_n),
    .key(LEFT),
    .update(LEFT_ns)
);

key_filter key_filter_right(
    .clk(clk_25M),
    .rst_n(rst_n),
    .key(RIGHT),
    .update(RIGHT_ns)
);

key_filter key_filter_up(
    .clk(clk_25M),
    .rst_n(rst_n),
    .key(UP),
    .update(UP_ns)
);

key_filter key_filter_down(
    .clk(clk_25M),
    .rst_n(rst_n),
    .key(DOWN),
    .update(DOWN_ns)
);

state_machine state_machine_inst(
    .clk(clk_25M),
    .rst_n(rst_n),
    .up(UP_ns),
    .down(DOWN_ns),
    .right(RIGHT_ns),
    .left(LEFT_ns),
    .UP_bluetooth(UP_bluetooth),
    .DOWN_bluetooth(DOWN_bluetooth),
    .LEFT_bluetooth(LEFT_bluetooth),
    .RIGHT_bluetooth(RIGHT_bluetooth),
    .switch_J15(switch_J15),
    .switch_M13(switch_M13),
    .flag_isdead(flag_isdead),
    .general_state(general_state),
    .move_state(move_state),
    .difficulty_state(difficulty_state)
);

random_xy random_xy_inst(
    .clk(clk_25M),
    .rst_n(rst_n),
    .rand_x(random_x),
    .rand_y(random_y),
    .snake_x(snake_x),
    .snake_y(snake_y),
    .snake_length(snake_length)
);

vga vga_inst(
    .clk(clk_25M), 
    .rst_n(rst_n), 
    .general_state(general_state),
    .difficulty_state(difficulty_state),
    .move_state(move_state),
    .random_x(random_x),
    .random_y(random_y),
    .O_red(O_red),
    .O_green(O_green),
    .O_blue(O_blue),
    .flag_isdead(flag_isdead),
    .snake_x(snake_x),
    .snake_y(snake_y),
    .snake_length(snake_length),
    .O_hs(O_hs),
    .O_vs(O_vs)
);

uart_rx uart_rx_inst(
    .clk(clk_50M),
    .rst_n(rst_n), //低电平复位
    .rx(rx),//串口接收数据
    .po_flag(po_flag),//串转并后的数据有效标志信号
    .po_data(po_data)//有效数据
);

translate translate_inst(
    .clk(clk_25M),
    .rst_n(rst_n),
    .po_data(po_data),
    .UP_bluetooth(UP_bluetooth),
    .DOWN_bluetooth(DOWN_bluetooth),
    .LEFT_bluetooth(LEFT_bluetooth),
    .RIGHT_bluetooth(RIGHT_bluetooth)
);

endmodule

module reset(
    input in_rst,
    output rst_n
);
assign rst_n = (in_rst == 1)?1'b0:1'b1;
endmodule

module state_machine(
    input clk,
    input rst_n,
    input up,
    input down,
    input right,
    input left,
    input UP_bluetooth,
    input DOWN_bluetooth,
    input LEFT_bluetooth,
    input RIGHT_bluetooth, 
    input switch_J15,
    input switch_M13,
    input flag_isdead,
    output reg [1:0] general_state,
    output reg [1:0] difficulty_state,
    output reg [4:0] move_state
);
//游戏难度状�??
parameter hard = 2'b00;//难度1-�?
parameter mid = 2'b01;//难度2-中等
parameter easy = 2'b10;//难度3-�?

//总画面状态
parameter start = 2'b00;//初始界面
parameter diff_menu = 2'b01;//难度选择界面
parameter game_start = 2'b10;//游戏准备开始
parameter gaming = 2'b11;//游戏中

//游戏时移动朝向状�?

parameter stop = 5'b00001;//暂停
parameter face_up = 5'b00010;//朝上
parameter face_down = 5'b00100;//朝下
parameter face_left = 5'b01000;//朝左
parameter face_right = 5'b10000;//朝右

//总状态机
always@(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        general_state <= start;
    end
    else begin
        case (general_state) 
        start: 
        if (up == 1'b0 && down == 1'b1 && left == 1'b0 && right == 1'b0) begin
            general_state <= diff_menu;
        end
        else if (switch_J15 == 1'b1) begin
            general_state <= game_start;
        end
        else begin
            general_state <= start;
        end

        diff_menu:
        if (up == 1'b1 && down == 1'b0 && left == 1'b0 && right == 1'b0) begin
            general_state <= start;
        end
        else begin
            general_state <= general_state;
        end

        game_start:
        if (up == 1'b0 && down == 1'b0 && left == 1'b0 && right == 1'b1) begin
            //move_state <= face_right;
            general_state <= gaming;
        end
        else begin
            general_state <= game_start;
        end

        gaming:
        if (switch_M13 == 1'b1) begin
            general_state <= game_start;
        end
        else begin
            general_state <= gaming;
        end

        default: general_state <= start;
        endcase
    end
end

//难度选择状�?�机
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        difficulty_state <= easy;
    end
    else if(general_state == diff_menu) begin
        case (difficulty_state)
        easy: 
        if (up == 1'b0 && down == 1'b0 && left == 1'b0 && right == 1'b1) begin
            difficulty_state <= mid;
        end
        else begin
            difficulty_state <= easy;
        end
        
        mid:
        if (up == 1'b0 && down == 1'b0 && left == 1'b1 && right == 1'b0) begin
            difficulty_state <= easy;
        end
        else if(up == 1'b0 && down == 1'b0 && left == 1'b0 && right == 1'b1) begin
            difficulty_state <= hard;
        end
        else begin
            difficulty_state <= mid;
        end

        hard:
        if (up == 1'b0 && down == 1'b0 && left == 1'b1 && right == 1'b0) begin
            difficulty_state <= mid;
        end
        else begin
            difficulty_state <= hard;
        end
        endcase
    end
end

//蛇移动朝向状态机
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        move_state<=stop;
    end

    else if(general_state==game_start)
    begin
        move_state<=stop;
    end

    else if(flag_isdead == 1)
    begin
        move_state<=stop;
    end

    else if(general_state==gaming)
    begin
        case(move_state)
	    stop:
        if(RIGHT_bluetooth == 1'b1 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_right;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b1 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= stop;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b1 && UP_bluetooth == 1'b0)
			move_state <= face_down;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b1)
			move_state <= face_up;
        else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
            move_state <= stop;
        else 
            move_state <= stop;

	    face_left:
        if(RIGHT_bluetooth == 1'b1 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_left;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b1 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_left;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b1 && UP_bluetooth == 1'b0)
			move_state <= face_down;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b1)
			move_state <= face_up;
        else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
            move_state <= face_left;
        else 
            move_state <= face_left;

	    face_right:
        if(RIGHT_bluetooth == 1'b1 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_right;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b1 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_right;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b1 && UP_bluetooth == 1'b0)
			move_state <= face_down;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b1)
			move_state <= face_up;
        else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
            move_state <= face_right;
        else 
            move_state <= face_right;

	    face_up:
        if(RIGHT_bluetooth == 1'b1 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_right;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b1 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_left;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b1 && UP_bluetooth == 1'b0)
			move_state <= face_up;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b1)
			move_state <= face_up;
        else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
            move_state <= face_up;
        else 
            move_state <= face_up;

	    face_down:
        if(RIGHT_bluetooth == 1'b1 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_right;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b1 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
			move_state <= face_left;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b1 && UP_bluetooth == 1'b0)
			move_state <= face_down;
		else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b1)
			move_state <= face_down;
        else if(RIGHT_bluetooth == 1'b0 && LEFT_bluetooth == 1'b0 && DOWN_bluetooth == 1'b0 && UP_bluetooth == 1'b0)
            move_state <= face_down;
        else 
            move_state <= face_down;

	    default:
            move_state <= stop;

	    endcase
    end
	
end

endmodule

module vga
(
    input clk   , // 系统100MHz时钟
    input rst_n , // 系统复位
    input [1:0] general_state,
    input [1:0] difficulty_state,
    input [4:0] move_state,
    input [4:0] random_x,
    input [4:0] random_y,
    output reg [3:0] O_red,// VGA红色分量
    output reg [3:0] O_green,// VGA绿色分量
    output reg [3:0] O_blue,// VGA蓝色分量
    output reg [199:0] snake_x,
    output reg [199:0] snake_y,
    output reg [9:0] snake_length,
    output O_hs,// VGA行同步信�?
    output reg flag_isdead,
    output O_vs// VGA场同步信�?
);
parameter start = 2'b00;//�?始界�?
parameter diff_menu = 2'b01;//选择难度菜单
parameter game_start = 2'b10;//游戏初始状�??
parameter gaming = 2'b11;//游戏�?

parameter hard = 2'b00;//难度1-�?
parameter mid = 2'b01;//难度2-中等
parameter easy = 2'b10;//难度3-�?

parameter length_init = 3;//蛇初始长度为3
parameter headx_init = 340;//蛇头初始x坐标
parameter heady_init = 240;//蛇头初始y坐标

parameter stop = 5'b00001;//初始停止状态
parameter face_up = 5'b00010;//朝上
parameter face_down = 5'b00100;//朝下
parameter face_left = 5'b01000;//朝左
parameter face_right = 5'b10000;//朝右

parameter square_length = 20;
parameter square_width = 24;

reg [29:0] stay_cnt;//蛇在每一格停留时长计数器
reg [29:0] interval;//蛇在每一格停留的时间间隔
//reg [9:0] snake_x [19:0];//蛇身横坐标寄存器
//reg [9:0] snake_y [19:0];//蛇身纵坐标寄存器
//reg [9:0] snake_length;//蛇长寄存器

reg[9:0] food_x;//食物横坐标
reg[8:0] food_y;//食物纵坐标
reg flag_food;//判断是否需要生成新的食物标志
wire issnake;//判断是否要显示蛇身
wire issnake_green;//绿色蛇身
wire issnake_blue;//蓝色蛇身
wire issnake_pink;//粉色蛇身
wire isfood;//判断是否要显示食物
wire h_issnake;
wire v_issnake;
wire h_isfood;
wire v_isfood;
wire flag_printnew;//到达指定难度对应时间间隔，需要显示新内容
//reg flag_isdead;//判断蛇是否死亡标志

// 分辨率为640*480时行时序各个参数定义
parameter   C_H_SYNC_PULSE      =   96  , 
            C_H_BACK_PORCH      =   48  ,
            C_H_ACTIVE_TIME     =   640 ,
            C_H_FRONT_PORCH     =   16  ,
            C_H_LINE_PERIOD     =   800 ;

// 分辨率为640*480时场时序各个参数定义               
parameter   C_V_SYNC_PULSE      =   2   , 
            C_V_BACK_PORCH      =   33  ,
            C_V_ACTIVE_TIME     =   480 ,
            C_V_FRONT_PORCH     =   10  ,
            C_V_FRAME_PERIOD    =   525 ;

parameter   h_before = C_H_SYNC_PULSE + C_H_BACK_PORCH;
parameter   h_after = C_H_LINE_PERIOD - C_H_FRONT_PORCH;
parameter   v_before = C_V_SYNC_PULSE + C_V_BACK_PORCH;
parameter   v_after = C_V_FRAME_PERIOD - C_V_FRONT_PORCH;

                
reg [11:0]      R_h_cnt         ; // 行时序计数器
reg [11:0]      R_v_cnt         ; // 列时序计数器
wire            W_active_flag   ; // �?活标志，当这个信号为1时RGB的数据可以显示在屏幕�?

//////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        R_h_cnt <=  12'd0   ;
    else if(R_h_cnt == C_H_LINE_PERIOD - 1'b1)
        R_h_cnt <=  12'd0   ;
    else
        R_h_cnt <=  R_h_cnt + 1'b1  ;                
end                

assign O_hs =   (R_h_cnt < C_H_SYNC_PULSE) ? 1'b0 : 1'b1    ; 
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        R_v_cnt <=  12'd0   ;
    else if(R_v_cnt == C_V_FRAME_PERIOD - 1'b1)
        R_v_cnt <=  12'd0   ;
    else if(R_h_cnt == C_H_LINE_PERIOD - 1'b1)
        R_v_cnt <=  R_v_cnt + 1'b1  ;
    else
        R_v_cnt <=  R_v_cnt ;                        
end                

assign O_vs =   (R_v_cnt < C_V_SYNC_PULSE) ? 1'b0 : 1'b1    ; 
//////////////////////////////////////////////////////////////////  

assign W_active_flag =  (R_h_cnt >= h_before)  &&
                        (R_h_cnt < h_after)  && 
                        (R_v_cnt >= v_before)  &&
                        (R_v_cnt < v_after);

assign h_issnake = 
    //!flag_isdead &&
    (R_h_cnt >= h_before + snake_x[9:0] && R_h_cnt < h_before + snake_x[9:0] + square_length) ||
    (R_h_cnt >= h_before + snake_x[19:10] && R_h_cnt < h_before + snake_x[19:10] + square_length) ||
    (R_h_cnt >= h_before + snake_x[29:20] && R_h_cnt < h_before + snake_x[29:20] + square_length) ||
    (R_h_cnt >= h_before + snake_x[39:30] && R_h_cnt < h_before + snake_x[39:30] + square_length && snake_length >= 4) ||
    (R_h_cnt >= h_before + snake_x[49:40] && R_h_cnt < h_before + snake_x[49:40] + square_length && snake_length >= 5) ||
    (R_h_cnt >= h_before + snake_x[59:50] && R_h_cnt < h_before + snake_x[59:50] + square_length && snake_length >= 6) ||
    (R_h_cnt >= h_before + snake_x[69:60] && R_h_cnt < h_before + snake_x[69:60] + square_length && snake_length >= 7) ||
    (R_h_cnt >= h_before + snake_x[79:70] && R_h_cnt < h_before + snake_x[79:70] + square_length && snake_length >= 8) ||
    (R_h_cnt >= h_before + snake_x[89:80] && R_h_cnt < h_before + snake_x[89:80] + square_length && snake_length >= 9) ||
    (R_h_cnt >= h_before + snake_x[99:90] && R_h_cnt < h_before + snake_x[99:90] + square_length && snake_length >= 10) ||
    (R_h_cnt >= h_before + snake_x[109:100] && R_h_cnt < h_before + snake_x[109:100] + square_length && snake_length >= 11) ||
    (R_h_cnt >= h_before + snake_x[119:110] && R_h_cnt < h_before + snake_x[119:110] + square_length && snake_length >= 12) ||
    (R_h_cnt >= h_before + snake_x[129:120] && R_h_cnt < h_before + snake_x[129:120] + square_length && snake_length >= 13) || 
    (R_h_cnt >= h_before + snake_x[139:130] && R_h_cnt < h_before + snake_x[139:130] + square_length && snake_length >= 14) || 
    (R_h_cnt >= h_before + snake_x[149:140] && R_h_cnt < h_before + snake_x[149:140] + square_length && snake_length >= 15) || 
    (R_h_cnt >= h_before + snake_x[159:150] && R_h_cnt < h_before + snake_x[159:150] + square_length && snake_length >= 16) || 
    (R_h_cnt >= h_before + snake_x[169:160] && R_h_cnt < h_before + snake_x[169:160] + square_length && snake_length >= 17) || 
    (R_h_cnt >= h_before + snake_x[179:170] && R_h_cnt < h_before + snake_x[179:170] + square_length && snake_length >= 18) || 
    (R_h_cnt >= h_before + snake_x[189:180] && R_h_cnt < h_before + snake_x[189:180] + square_length && snake_length >= 19) || 
    (R_h_cnt >= h_before + snake_x[199:190] && R_h_cnt < h_before + snake_x[199:190] + square_length && snake_length == 20);

assign v_issnake = 
    //!flag_isdead &&
    (R_v_cnt >= v_before + snake_y[9:0] && R_v_cnt < v_before + snake_y[9:0] + square_width) ||
    (R_v_cnt >= v_before + snake_y[19:10] && R_v_cnt < v_before + snake_y[19:10] + square_width) ||
    (R_v_cnt >= v_before + snake_y[29:20] && R_v_cnt < v_before + snake_y[29:20] + square_width) ||
    (R_v_cnt >= v_before + snake_y[39:30] && R_v_cnt < v_before + snake_y[39:30] + square_width && snake_length >= 4) ||
    (R_v_cnt >= v_before + snake_y[49:40] && R_v_cnt < v_before + snake_y[49:40] + square_width && snake_length >= 5) ||
    (R_v_cnt >= v_before + snake_y[59:50] && R_v_cnt < v_before + snake_y[59:50] + square_width && snake_length >= 6) ||
    (R_v_cnt >= v_before + snake_y[69:60] && R_v_cnt < v_before + snake_y[69:60] + square_width && snake_length >= 7) ||
    (R_v_cnt >= v_before + snake_y[79:70] && R_v_cnt < v_before + snake_y[79:70] + square_width && snake_length >= 8) ||
    (R_v_cnt >= v_before + snake_y[89:80] && R_v_cnt < v_before + snake_y[89:80] + square_width && snake_length >= 9) ||
    (R_v_cnt >= v_before + snake_y[99:90] && R_v_cnt < v_before + snake_y[99:90] + square_width && snake_length >= 10) ||
    (R_v_cnt >= v_before + snake_y[109:100] && R_v_cnt < v_before + snake_y[109:100] + square_width && snake_length >= 11) ||
    (R_v_cnt >= v_before + snake_y[119:110] && R_v_cnt < v_before + snake_y[119:110] + square_width && snake_length >= 12) ||
    (R_v_cnt >= v_before + snake_y[129:120] && R_v_cnt < v_before + snake_y[129:120] + square_width && snake_length >= 13) || 
    (R_v_cnt >= v_before + snake_y[139:130] && R_v_cnt < v_before + snake_y[139:130] + square_width && snake_length >= 14) || 
    (R_v_cnt >= v_before + snake_y[149:140] && R_v_cnt < v_before + snake_y[149:140] + square_width && snake_length >= 15) || 
    (R_v_cnt >= v_before + snake_y[159:150] && R_v_cnt < v_before + snake_y[159:150] + square_width && snake_length >= 16) || 
    (R_v_cnt >= v_before + snake_y[169:160] && R_v_cnt < v_before + snake_y[169:160] + square_width && snake_length >= 17) || 
    (R_v_cnt >= v_before + snake_y[179:170] && R_v_cnt < v_before + snake_y[179:170] + square_width && snake_length >= 18) || 
    (R_v_cnt >= v_before + snake_y[189:180] && R_v_cnt < v_before + snake_y[189:180] + square_width && snake_length >= 19) || 
    (R_v_cnt >= v_before + snake_y[199:190] && R_v_cnt < v_before + snake_y[199:190] + square_width && snake_length == 20);

assign issnake = h_issnake && v_issnake;

assign issnake_green = (
 ((R_v_cnt >= v_before + snake_y[9:0] && R_v_cnt < v_before + snake_y[9:0] + square_width)
&&(R_h_cnt >= h_before + snake_x[9:0] && R_h_cnt < h_before + snake_x[9:0] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[39:30] && R_v_cnt < v_before + snake_y[39:30] + square_width)
&&(R_h_cnt >= h_before + snake_x[39:30] && R_h_cnt < h_before + snake_x[39:30] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[69:60] && R_v_cnt < v_before + snake_y[69:60] + square_width)
&&(R_h_cnt >= h_before + snake_x[69:60] && R_h_cnt < h_before + snake_x[69:60] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[99:90] && R_v_cnt < v_before + snake_y[99:90] + square_width)
&&(R_h_cnt >= h_before + snake_x[99:90] && R_h_cnt < h_before + snake_x[99:90] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[129:120] && R_v_cnt < v_before + snake_y[129:120] + square_width)
&&(R_h_cnt >= h_before + snake_x[129:120] && R_h_cnt < h_before + snake_x[129:120] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[159:150] && R_v_cnt < v_before + snake_y[159:150] + square_width)
&&(R_h_cnt >= h_before + snake_x[159:150] && R_h_cnt < h_before + snake_x[159:150] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[189:180] && R_v_cnt < v_before + snake_y[189:180] + square_width)
&&(R_h_cnt >= h_before + snake_x[189:180] && R_h_cnt < h_before + snake_x[189:180] + square_length))
);
assign issnake_blue = (
 ((R_v_cnt >= v_before + snake_y[19:10] && R_v_cnt < v_before + snake_y[19:10] + square_width)
&&(R_h_cnt >= h_before + snake_x[19:10] && R_h_cnt < h_before + snake_x[19:10] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[49:40] && R_v_cnt < v_before + snake_y[49:40] + square_width)
&&(R_h_cnt >= h_before + snake_x[49:40] && R_h_cnt < h_before + snake_x[49:40] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[79:70] && R_v_cnt < v_before + snake_y[79:70] + square_width)
&&(R_h_cnt >= h_before + snake_x[79:70] && R_h_cnt < h_before + snake_x[79:70] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[109:100] && R_v_cnt < v_before + snake_y[109:100] + square_width)
&&(R_h_cnt >= h_before + snake_x[109:100] && R_h_cnt < h_before + snake_x[109:100] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[139:130] && R_v_cnt < v_before + snake_y[139:130] + square_width)
&&(R_h_cnt >= h_before + snake_x[139:130] && R_h_cnt < h_before + snake_x[139:130] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[169:160] && R_v_cnt < v_before + snake_y[169:160] + square_width)
&&(R_h_cnt >= h_before + snake_x[169:160] && R_h_cnt < h_before + snake_x[169:160] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[199:190] && R_v_cnt < v_before + snake_y[199:190] + square_width)
&&(R_h_cnt >= h_before + snake_x[199:190] && R_h_cnt < h_before + snake_x[199:190] + square_length))
);
assign issnake_pink = (
 ((R_v_cnt >= v_before + snake_y[29:20] && R_v_cnt < v_before + snake_y[29:20] + square_width)
&&(R_h_cnt >= h_before + snake_x[29:20] && R_h_cnt < h_before + snake_x[29:20] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[59:50] && R_v_cnt < v_before + snake_y[59:50] + square_width)
&&(R_h_cnt >= h_before + snake_x[59:50] && R_h_cnt < h_before + snake_x[59:50] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[89:80] && R_v_cnt < v_before + snake_y[89:80] + square_width)
&&(R_h_cnt >= h_before + snake_x[89:80] && R_h_cnt < h_before + snake_x[89:80] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[119:110] && R_v_cnt < v_before + snake_y[119:110] + square_width)
&&(R_h_cnt >= h_before + snake_x[119:110] && R_h_cnt < h_before + snake_x[119:110] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[149:140] && R_v_cnt < v_before + snake_y[149:140] + square_width)
&&(R_h_cnt >= h_before + snake_x[149:140] && R_h_cnt < h_before + snake_x[149:140] + square_length)) ||
 ((R_v_cnt >= v_before + snake_y[179:170] && R_v_cnt < v_before + snake_y[179:170] + square_width)
&&(R_h_cnt >= h_before + snake_x[179:170] && R_h_cnt < h_before + snake_x[179:170] + square_length))
);


assign h_isfood = (R_h_cnt >= h_before + food_x) && (R_h_cnt < h_before + food_x + square_length);
assign v_isfood = (R_v_cnt >= v_before + food_y) && (R_v_cnt < v_before + food_y + square_width);
assign isfood = h_isfood && v_isfood;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n) 
    begin  
        O_red   <=  4'b0000;
        O_green <=  4'b0000;
        O_blue  <=  4'b0000; 
    end
    else if(W_active_flag)
    begin
        case (general_state) 
        start:
        begin
            O_red   <=  4'b0000;
            O_green <=  4'b0000;
            O_blue  <=  4'b0000; 
        end

        diff_menu:
        begin
            case (difficulty_state) 
            easy:
            begin
            if (R_v_cnt >= v_before + 220 && R_v_cnt < v_before + 260) 
            begin
                if (R_h_cnt >= h_before + 220 && R_h_cnt < h_before + 260) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b0000; 
                end//end of if11
                else if(R_h_cnt >= h_before + 300 && R_h_cnt < h_before + 340
                     || R_h_cnt >= h_before + 380 && R_h_cnt < h_before + 420) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b1111;
                end//end of else if11
                else begin
                    O_red   <=  4'b1111;
                    O_green <=  4'b1111;
                    O_blue  <=  4'b1111; 
                end//end of else1
            end//end of if21
            else
            begin
                O_red   <=  4'b1111;
                O_green <=  4'b1111;
                O_blue  <=  4'b1111;  
            end//end of else 21
            end//end of easy
            
            mid:
            begin
            if (R_v_cnt >= v_before + 220 && R_v_cnt < v_before + 260) 
            begin
                if (R_h_cnt >= h_before + 300 && R_h_cnt < h_before + 340) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b0000; 
                end//end of if11
                else if(R_h_cnt >= h_before + 220 && R_h_cnt < h_before + 260
                     || R_h_cnt >= h_before + 380 && R_h_cnt < h_before + 420) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b1111;
                end//end of else if11
                else begin
                    O_red   <=  4'b1111;
                    O_green <=  4'b1111;
                    O_blue  <=  4'b1111; 
                end//end of else1
            end//end of if21
            else   
            begin           
                O_red   <=  4'b1111;
                O_green <=  4'b1111;
                O_blue  <=  4'b1111;  
            end
            end//end of mid

            hard:
            begin
            if (R_v_cnt >= v_before + 220 && R_v_cnt < v_before + 260) 
            begin
                if (R_h_cnt >= h_before + 380 && R_h_cnt < h_before + 420) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b0000; 
                end
                else if(R_h_cnt >= h_before + 300 && R_h_cnt < h_before + 340
                     || R_h_cnt >= h_before + 220 && R_h_cnt < h_before + 260) 
                begin
                    O_red   <=  4'b0000;
                    O_green <=  4'b0000;
                    O_blue  <=  4'b1111;
                end
                else begin
                    O_red   <=  4'b1111;
                    O_green <=  4'b1111;
                    O_blue  <=  4'b1111; 
                end
            end
            else
            begin           
                O_red   <=  4'b1111;
                O_green <=  4'b1111;
                O_blue  <=  4'b1111;  
            end
            end//end of hard
            endcase
        end

        game_start:
        begin
            if
            (
            (R_h_cnt >= h_before + snake_x[9:0] && R_h_cnt < h_before + snake_x[9:0] + square_length
            && R_v_cnt >= v_before + snake_y[9:0] && R_v_cnt < v_before + snake_y[9:0] + square_width)
            ||(R_h_cnt >= h_before + snake_x[19:10] && R_h_cnt < h_before + snake_x[19:10] + square_length
            && R_v_cnt >= v_before + snake_y[19:10] && R_v_cnt < v_before + snake_y[19:10] + square_width)
            ||(R_h_cnt >= h_before + snake_x[29:20] && R_h_cnt < h_before + snake_x[29:20] + square_length
            && R_v_cnt >= v_before + snake_y[29:20] && R_v_cnt < v_before + snake_y[29:20] + square_width)
            ) 
            begin
                O_red   <=  4'b0000;
                O_green <=  4'b1111;
                O_blue  <=  4'b0000;
            end
            else
            begin
                O_red   <=  4'b1111;
                O_green <=  4'b1111;
                O_blue  <=  4'b1111;
            end
        end

        gaming:
        begin
            if (isfood == 1) 
            begin
                O_red   <=  4'b1111;
                O_green <=  4'b0000;
                O_blue  <=  4'b0000;
            end
            
            else if(issnake_green == 1 && issnake == 1)
            begin
                O_red   <=  4'b0000;
                O_green <=  4'b1111;
                O_blue  <=  4'b0000;
            end
            else if(issnake_blue == 1 && issnake == 1)
            begin
                O_red   <=  4'b0000;
                O_green <=  4'b0000;
                O_blue  <=  4'b1111;
            end
            else if(issnake_pink == 1 && issnake == 1)
            begin
                O_red   <=  4'b1111;
                O_green <=  4'b0000;
                O_blue  <=  4'b1111;
            end
            
            else 
            begin
                O_red   <=  4'b1111;
                O_green <=  4'b1111;
                O_blue  <=  4'b1111;
            end
        end

        default: 
        begin
            O_red   <=  4'b0000;
            O_green <=  4'b0000;
            O_blue  <=  4'b0000; 
        end
        endcase
        
    end
    
    else
        begin
            O_red   <=  4'b0000;
            O_green <=  4'b0000;
            O_blue  <=  4'b0000; 
        end   
    
end

//pause计数器
always@(posedge clk or negedge rst_n)
if (!rst_n)
	stay_cnt <= 0;
else if(general_state == game_start)
    stay_cnt <= 0;
else if (stay_cnt < interval - 1 && general_state == gaming && move_state != stop)
	stay_cnt <= stay_cnt + 1'b1;
else if (stay_cnt == interval - 1 && general_state == gaming && move_state != stop)
	stay_cnt <= 0;

assign flag_printnew = (stay_cnt == interval - 1)?1'b1:1'b0;

//难度控制
always@(posedge clk or negedge rst_n)
if (!rst_n)
	interval <= 2000_0000;//0.8s
else if (difficulty_state == easy && general_state == diff_menu)
	interval <= 2000_0000;//0.8s
else if (difficulty_state == mid && general_state == diff_menu)
	interval <= 1000_0000;//0.4s
else if (difficulty_state == hard && general_state == diff_menu)
	interval <= 500_0000;//0.2s
else
    interval <= interval;

//蛇长计数
always@(posedge clk or negedge rst_n)
if(!rst_n)
	snake_length <= length_init;
else if(general_state == game_start)
	snake_length <= length_init;
else if(flag_food==1)
	snake_length <= snake_length+1;
else if(snake_length==20)
    snake_length <= snake_length;
else
    snake_length <= snake_length;

//判断食物是否应该刷新
always@(posedge clk or negedge rst_n)
if(!rst_n)
	flag_food <= 0;
else if(food_x == snake_x[9:0] && food_y == snake_y[9:0] && general_state == gaming)
	flag_food <= 1;
else 
	flag_food <= 0;

//食物横坐标
always@(posedge clk or negedge rst_n)
if(!rst_n)
	food_x <= 0;
else if(flag_food == 1)
	food_x <= random_x * square_length;
else if(general_state==game_start)
	food_x <= random_x * square_length;

//食物纵坐标
always@(posedge clk or negedge rst_n)
if(!rst_n)
	food_y <= 0;
else if(flag_food == 1)
	food_y <= random_y * square_width;
else if(general_state==game_start)
	food_y <= random_y * square_width;

//判断蛇是否死亡
always@(posedge clk or negedge rst_n)
if (!rst_n)
	flag_isdead <= 0;
else if(general_state == game_start)
	flag_isdead <= 0;
else if(flag_isdead == 0)
begin
	if (snake_x[9:0]<0 || snake_x[9:0]>640 - square_length || snake_y[9:0]<0 || snake_y[9:0]>480 - square_width)
		flag_isdead <= 1;
    
	else if (snake_x[9:0]==snake_x[19:10] && snake_y[9:0]==snake_y[19:10])
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[29:20] && snake_y[9:0]==snake_y[29:20])
		flag_isdead <= 1;
    
	else if (snake_x[9:0]==snake_x[39:30] && snake_y[9:0]==snake_y[39:30] && snake_length >= 4)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[49:40] && snake_y[9:0]==snake_y[49:40] && snake_length >= 5)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[59:50] && snake_y[9:0]==snake_y[59:50] && snake_length >= 6)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[69:60] && snake_y[9:0]==snake_y[69:60] && snake_length >= 7)
		flag_isdead <= 1;
    else if (snake_x[9:0]==snake_x[79:70] && snake_y[9:0]==snake_y[79:70] && snake_length >= 8)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[89:80] && snake_y[9:0]==snake_y[89:80] && snake_length >= 9)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[99:90] && snake_y[9:0]==snake_y[99:90] && snake_length >= 10)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[109:100] && snake_y[9:0]==snake_y[109:100] && snake_length >= 11)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[119:110] && snake_y[9:0]==snake_y[119:110] && snake_length >= 12)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[129:120] && snake_y[9:0]==snake_y[129:120] && snake_length >= 13)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[139:130] && snake_y[9:0]==snake_y[139:130] && snake_length >= 14)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[149:140] && snake_y[9:0]==snake_y[149:140] && snake_length >= 15)
		flag_isdead <= 1;
    else if (snake_x[9:0]==snake_x[159:150] && snake_y[9:0]==snake_y[159:150] && snake_length >= 16)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[169:160] && snake_y[9:0]==snake_y[169:160] && snake_length >= 17)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[179:170] && snake_y[9:0]==snake_y[179:170] && snake_length >= 18)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[189:180] && snake_y[9:0]==snake_y[189:180] && snake_length >= 19)
		flag_isdead <= 1;
	else if (snake_x[9:0]==snake_x[199:190] && snake_y[9:0]==snake_y[199:190] && snake_length >= 20)
		flag_isdead <= 1;
	else
		flag_isdead <= 0;
end

//蛇身的移动
always@(posedge clk or negedge rst_n)
if(!rst_n) 
begin
    snake_x[9:0] <= headx_init;                     snake_y[9:0] <= heady_init;

    snake_x[19:10] <= headx_init - square_length;   snake_y[19:10] = heady_init;
    snake_x[29:20] <= headx_init - 2*square_length; snake_y[29:20] <= heady_init;
    snake_x[39:30] <= 0; snake_y[39:30] <= 0;
    snake_x[49:40] <= 0; snake_y[49:40] <= 0;
    snake_x[59:50] <= 0; snake_y[59:50] <= 0;
    snake_x[69:60] <= 0; snake_y[69:60] <= 0;
    snake_x[79:70] <= 0; snake_y[79:70] <= 0;
    snake_x[89:80] <= 0; snake_y[89:80] <= 0;
    snake_x[99:90] <= 0; snake_y[99:90] <= 0;
    snake_x[109:100] <= 0; snake_y[109:100] <= 0;
    snake_x[119:110] <= 0; snake_y[119:110] <= 0;
    snake_x[129:120] <= 0; snake_y[129:120] <= 0;
    snake_x[139:130] <= 0; snake_y[139:130] <= 0;
    snake_x[149:140] <= 0; snake_y[149:140] <= 0;
    snake_x[159:150] <= 0; snake_y[159:150] <= 0;
    snake_x[169:160] <= 0; snake_y[169:160] <= 0;
    snake_x[179:170] <= 0; snake_y[179:170] <= 0;
    snake_x[189:180] <= 0; snake_y[189:180] <= 0;
    snake_x[199:190] <= 0; snake_y[199:190] <= 0;
end
else if (general_state == game_start) 
begin
    snake_x[9:0] <= headx_init;                     snake_y[9:0] <= heady_init;

    snake_x[19:10] <= headx_init - square_length;   snake_y[19:10] = heady_init;
    snake_x[29:20] <= headx_init - 2*square_length; snake_y[29:20] <= heady_init;
    snake_x[39:30] <= 0; snake_y[39:30] <= 0;
    snake_x[49:40] <= 0; snake_y[49:40] <= 0;
    snake_x[59:50] <= 0; snake_y[59:50] <= 0;
    snake_x[69:60] <= 0; snake_y[69:60] <= 0;
    snake_x[79:70] <= 0; snake_y[79:70] <= 0;
    snake_x[89:80] <= 0; snake_y[89:80] <= 0;
    snake_x[99:90] <= 0; snake_y[99:90] <= 0;
    snake_x[109:100] <= 0; snake_y[109:100] <= 0;
    snake_x[119:110] <= 0; snake_y[119:110] <= 0;
    snake_x[129:120] <= 0; snake_y[129:120] <= 0;
    snake_x[139:130] <= 0; snake_y[139:130] <= 0;
    snake_x[149:140] <= 0; snake_y[149:140] <= 0;
    snake_x[159:150] <= 0; snake_y[159:150] <= 0;
    snake_x[169:160] <= 0; snake_y[169:160] <= 0;
    snake_x[179:170] <= 0; snake_y[179:170] <= 0;
    snake_x[189:180] <= 0; snake_y[189:180] <= 0;
    snake_x[199:190] <= 0; snake_y[199:190] <= 0;
end
else if(move_state == stop)
begin
    snake_x[9:0] <= snake_x[9:0]; 
    snake_y[9:0] <= snake_y[9:0];
    snake_x[19:10] <= snake_x[19:10]; 
    snake_y[19:10] <= snake_y[19:10];
    snake_x[29:20] <= snake_x[29:20]; 
    snake_y[29:20] <= snake_y[29:20];
    snake_x[39:30] <= snake_x[39:30]; 
    snake_y[39:30] <= snake_y[39:30];
    snake_x[49:40] <= snake_x[49:40]; 
    snake_y[49:40] <= snake_y[49:40];
    snake_x[59:50] <= snake_x[59:50]; 
    snake_y[59:50] <= snake_y[59:50];
    snake_x[69:60] <= snake_x[69:60]; 
    snake_y[69:60] <= snake_y[69:60];
    snake_x[79:70] <= snake_x[79:70]; 
    snake_y[79:70] <= snake_y[79:70];
    snake_x[89:80] <= snake_x[89:80]; 
    snake_y[89:80] <= snake_y[89:80];
    snake_x[99:90] <= snake_x[99:90]; 
    snake_y[99:90] <= snake_y[99:90];
    snake_x[109:100] <= snake_x[109:100]; 
    snake_y[109:100] <= snake_y[109:100];
    snake_x[119:110] <= snake_x[119:110]; 
    snake_y[119:110] <= snake_y[119:110];
    snake_x[129:120] <= snake_x[129:120]; 
    snake_y[129:120] <= snake_y[129:120];
    snake_x[139:130] <= snake_x[139:130]; 
    snake_y[139:130] <= snake_y[139:130];
    snake_x[149:140] <= snake_x[149:140]; 
    snake_y[149:140] <= snake_y[149:140];
    snake_x[159:150] <= snake_x[159:150]; 
    snake_y[159:150] <= snake_y[159:150];
    snake_x[169:160] <= snake_x[169:160];
    snake_y[169:160] <= snake_y[169:160];
    snake_x[179:170] <= snake_x[179:170]; 
    snake_y[179:170] <= snake_y[179:170];
    snake_x[189:180] <= snake_x[189:180]; 
    snake_y[189:180] <= snake_y[189:180];
    snake_x[199:190] <= snake_x[199:190]; 
    snake_y[199:190] <= snake_y[199:190];
end
else if(flag_printnew == 1 && move_state != stop && general_state == gaming)
begin
    case (move_state)
        face_right:
        begin  
            snake_x[9:0] <= snake_x[9:0] + square_length;
            snake_y[9:0] <= snake_y[9:0];
        end

        face_left: 
        begin
            snake_x[9:0] <= snake_x[9:0] - square_length;
            snake_y[9:0] <= snake_y[9:0];
        end

        face_up:
        begin
            snake_y[9:0] <= snake_y[9:0] - square_width;
            snake_x[9:0] <= snake_x[9:0];
        end

        face_down:
        begin
            snake_y[9:0] <= snake_y[9:0] + square_width;
            snake_x[9:0] <= snake_x[9:0];
        end
    endcase
    snake_x[19:10] <= snake_x[9:0]; snake_y[19:10] <= snake_y[9:0];
    snake_x[29:20] <= snake_x[19:10]; snake_y[29:20] <= snake_y[19:10];
    snake_x[39:30] <= snake_x[29:20]; snake_y[39:30] <= snake_y[29:20];
    snake_x[49:40] <= snake_x[39:30]; snake_y[49:40] <= snake_y[39:30];
    snake_x[59:50] <= snake_x[49:40]; snake_y[59:50] <= snake_y[49:40];
    snake_x[69:60] <= snake_x[59:50]; snake_y[69:60] <= snake_y[59:50];
    snake_x[79:70] <= snake_x[69:60]; snake_y[79:70] <= snake_y[69:60];
    snake_x[89:80] <= snake_x[79:70]; snake_y[89:80] <= snake_y[79:70];
    snake_x[99:90] <= snake_x[89:80]; snake_y[99:90] <= snake_y[89:80];
    snake_x[109:100] <= snake_x[99:90]; snake_y[109:100] <= snake_y[99:90];
    snake_x[119:110] <= snake_x[109:100]; snake_y[119:110] <= snake_y[109:100];
    snake_x[129:120] <= snake_x[119:110]; snake_y[129:120] <= snake_y[119:110];
    snake_x[139:130] <= snake_x[129:120]; snake_y[139:130] <= snake_y[129:120];
    snake_x[149:140] <= snake_x[139:130]; snake_y[149:140] <= snake_y[139:130];
    snake_x[159:150] <= snake_x[149:140]; snake_y[159:150] <= snake_y[149:140];
    snake_x[169:160] <= snake_x[159:150]; snake_y[169:160] <= snake_y[159:150];
    snake_x[179:170] <= snake_x[169:160]; snake_y[179:170] <= snake_y[169:160];
    snake_x[189:180] <= snake_x[179:170]; snake_y[189:180] <= snake_y[179:170];
    snake_x[199:190] <= snake_x[189:180]; snake_y[199:190] <= snake_y[189:180];
end

endmodule


module key_filter(
    input clk,
    input rst_n,
    input key,
    output reg update
);
parameter cnt_max = 20'd999_999;
reg[19:0]	cnt;

always@(posedge clk or negedge rst_n)
begin
if(!rst_n)
	cnt <= 0;
else if (key == 1'b1)
	cnt <= 0;
else if (cnt == cnt_max)
	cnt <= cnt_max;
else
	cnt <= cnt+1'b1;
end

always@(posedge clk or negedge rst_n)
if(!rst_n)
	update <= 0;
else if (cnt == cnt_max - 1)
    update <= 1;
else 
    update <= 0;
endmodule


module random_xy(
    input clk,				
    input rst_n,
    input [199:0] snake_x,
    input [199:0] snake_y,
    input [9:0] snake_length,
    output reg [4:0] rand_x,				//伪随机数输出值;
    output reg [4:0] rand_y
);
parameter square_length = 20;
parameter square_width = 24;
wire snake_coincide_rand;
assign snake_coincide_rand = (
(rand_x * square_length == snake_x[9:0] && rand_y * square_width == snake_y[9:0]) ||
(rand_x * square_length == snake_x[19:10] && rand_y * square_width == snake_y[19:10]) ||
(rand_x * square_length == snake_x[29:20] && rand_y * square_width == snake_y[29:20]) ||
(rand_x * square_length == snake_x[39:30] && rand_y * square_width == snake_y[39:30] && snake_length >= 4) ||
(rand_x * square_length == snake_x[49:40] && rand_y * square_width == snake_y[49:40] && snake_length >= 5) ||
(rand_x * square_length == snake_x[59:50] && rand_y * square_width == snake_y[59:50] && snake_length >= 6) ||
(rand_x * square_length == snake_x[69:60] && rand_y * square_width == snake_y[69:60] && snake_length >= 7) ||
(rand_x * square_length == snake_x[79:70] && rand_y * square_width == snake_y[79:70] && snake_length >= 8) ||
(rand_x * square_length == snake_x[89:80] && rand_y * square_width == snake_y[89:80] && snake_length >= 9) ||
(rand_x * square_length == snake_x[99:90] && rand_y * square_width == snake_y[99:90] && snake_length >= 10) ||
(rand_x * square_length == snake_x[109:100] && rand_y * square_width == snake_y[109:100] && snake_length >= 11) ||
(rand_x * square_length == snake_x[119:110] && rand_y * square_width == snake_y[119:110] && snake_length >= 12) ||
(rand_x * square_length == snake_x[129:120] && rand_y * square_width == snake_y[129:120] && snake_length >= 13) ||
(rand_x * square_length == snake_x[139:130] && rand_y * square_width == snake_y[139:130] && snake_length >= 14) ||
(rand_x * square_length == snake_x[149:140] && rand_y * square_width == snake_y[149:140] && snake_length >= 15) ||
(rand_x * square_length == snake_x[159:150] && rand_y * square_width == snake_y[159:150] && snake_length >= 16) ||
(rand_x * square_length == snake_x[169:160] && rand_y * square_width == snake_y[169:160] && snake_length >= 17) ||
(rand_x * square_length == snake_x[179:170] && rand_y * square_width == snake_y[179:170] && snake_length >= 18) ||
(rand_x * square_length == snake_x[189:180] && rand_y * square_width == snake_y[189:180] && snake_length >= 19) ||
(rand_x * square_length == snake_x[199:190] && rand_y * square_width == snake_y[199:190] && snake_length == 20)
);
//x
always@(posedge clk or negedge rst_n)
if (!rst_n)
	rand_x <= 0;
else
begin
    if (snake_coincide_rand == 1)
        rand_x <= 0;
    else
    begin
        if (rand_x == 31)
	        rand_x <= 0;
        else
	        rand_x <= rand_x+1;
    end

end
//y
always@(posedge clk or negedge rst_n)
if (!rst_n)
	rand_y <= 0;
else
begin
    if (snake_coincide_rand == 1)
        rand_y <= 0;
    else
    begin
        if (rand_y == 19 && rand_x == 31)
	        rand_y <= 0;
        else if (rand_x == 31)
	        rand_y <= rand_y+1;  
    end
end

endmodule 

//蓝牙模块
module uart_rx(
    input clk,   //时钟50MHz
    input rst_n, //低电平复位
    input rx,//串口接收数据
    output reg po_flag,//串转并后的数据有效标志信号
    output UP_bluetooth,
    output DOWN_bluetooth,
    output LEFT_bluetooth,
    output RIGHT_bluetooth,
    output reg [7:0] po_data//串行转并行后的8bit数据
);

localparam   UART_BPS    = 9600;//串口波特率
localparam   CLK_FREQ    = 50_000_000;//时钟频率
localparam  BAUD_CNT_MAX = CLK_FREQ/UART_BPS;

reg         rx_reg1     ;
reg         rx_reg2     ;
reg         rx_reg3     ;
reg         start_nedge ;
reg         work_en     ;
reg [12:0]  baud_cnt    ;
reg         bit_flag    ;
reg [3:0]   bit_cnt     ;
reg [7:0]   rx_data     ;
reg         rx_flag     ;

always@(posedge clk or negedge rst_n)
    if(!rst_n)
        rx_reg1 <= 1'b1;
    else
        rx_reg1 <= rx;

//rx_reg2:第二级寄存器，寄存器空闲状态复位为1
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        rx_reg2 <= 1'b1;
    else
        rx_reg2 <= rx_reg1;

//rx_reg3:第三级寄存器和第二级寄存器共同构成下降沿检测
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        rx_reg3 <= 1'b1;
    else
        rx_reg3 <= rx_reg2;

//start_nedge:检测到下降沿时start_nedge产生一个时钟的高电平
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        start_nedge <= 1'b0;
    else    if((~rx_reg2) && (rx_reg3))
        start_nedge <= 1'b1;
    else
        start_nedge <= 1'b0;

//work_en:接收数据工作使能信号
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        work_en <= 1'b0;
    else    if(start_nedge == 1'b1)
        work_en <= 1'b1;
    else    if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
        work_en <= 1'b0;

//baud_cnt:波特率计数器计数，从0计数到BAUD_CNT_MAX - 1
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        baud_cnt <= 13'b0;
    else    if((baud_cnt == BAUD_CNT_MAX - 1) || (work_en == 1'b0))
        baud_cnt <= 13'b0;
    else    if(work_en == 1'b1)
        baud_cnt <= baud_cnt + 1'b1;

//bit_flag:当baud_cnt计数器计数到中间数时采样的数据最稳定，
//此时拉高一个标志信号表示数据可以被取走
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        bit_flag <= 1'b0;
    else    if(baud_cnt == BAUD_CNT_MAX/2 - 1)
        bit_flag <= 1'b1;
    else
        bit_flag <= 1'b0;

//bit_cnt:有效数据个数计数器，当8个有效数据（不含起始位和停止位）
//都接收完成后计数器清零
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        bit_cnt <= 4'b0;
    else    if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
        bit_cnt <= 4'b0;
     else    if(bit_flag ==1'b1)
         bit_cnt <= bit_cnt + 1'b1;

//rx_data:输入数据进行移位
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        rx_data <= 8'b0;
    else    if((bit_cnt >= 4'd1)&&(bit_cnt <= 4'd8)&&(bit_flag == 1'b1))
        rx_data <= {rx_reg3, rx_data[7:1]};

//rx_flag:输入数据移位完成时rx_flag拉高一个时钟的高电平
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        rx_flag <= 1'b0;
    else    if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
        rx_flag <= 1'b1;
    else
        rx_flag <= 1'b0;

//po_data:输出完整的8位有效数据
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        po_data <= 8'b0;
    else    if(rx_flag == 1'b1)
        po_data <= rx_data;

//po_flag:输出数据有效标志（比rx_flag延后一个时钟周期，为了和po_data同步）
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        po_flag <= 1'b0;
    else
        po_flag <= rx_flag;

endmodule

module translate(
    input clk,
    input rst_n,
    input [7:0] po_data,
    output reg UP_bluetooth,
    output reg DOWN_bluetooth,
    output reg LEFT_bluetooth,
    output reg RIGHT_bluetooth    
);
always@(posedge clk or negedge rst_n)
if (!rst_n)
begin
    UP_bluetooth = 0;
    DOWN_bluetooth = 0;
    LEFT_bluetooth = 0;
    RIGHT_bluetooth = 0;
end
else
begin
    case (po_data)
    8'h01:
    begin
        UP_bluetooth = 1;
        //DOWN_bluetooth = 0;
        //LEFT_bluetooth = 0;
        //RIGHT_bluetooth = 0;
    end
    8'h02:
    begin
        //UP_bluetooth = 0;
        DOWN_bluetooth = 1;
        //LEFT_bluetooth = 0;
        //RIGHT_bluetooth = 0;
    end
    8'h03:
    begin
        //UP_bluetooth = 0;
        //DOWN_bluetooth = 0;
        LEFT_bluetooth = 1;
        //RIGHT_bluetooth = 0;
    end
    8'h04:
    begin
        //UP_bluetooth = 0;
        //DOWN_bluetooth = 0;
        //LEFT_bluetooth = 0;
        RIGHT_bluetooth = 1;
    end
    8'hf1:
    begin
        UP_bluetooth = 0;
        //DOWN_bluetooth = 0;
        //LEFT_bluetooth = 0;
        //RIGHT_bluetooth = 0;
    end
    8'hf2:
    begin
        //UP_bluetooth = 0;
        DOWN_bluetooth = 0;
        //LEFT_bluetooth = 0;
        //RIGHT_bluetooth = 0;
    end
    8'hf3:
    begin
        //UP_bluetooth = 0;
        //DOWN_bluetooth = 0;
        LEFT_bluetooth = 0;
        //RIGHT_bluetooth = 0;
    end
    8'hf4:
    begin
        //UP_bluetooth = 0;
        //DOWN_bluetooth = 0;
        //LEFT_bluetooth = 0;
        RIGHT_bluetooth = 0;
    end
    
    default:
    begin
        UP_bluetooth = 0;
        DOWN_bluetooth = 0;
        LEFT_bluetooth = 0;
        RIGHT_bluetooth = 0;
    end
    endcase
end
endmodule