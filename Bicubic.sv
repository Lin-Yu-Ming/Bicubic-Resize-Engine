
module Bicubic (
    input CLK,
    input RST,
    input enable,
    input [7:0] input_data,
    output logic [13:0] iaddr,
    output logic ird,
    output logic we,
    output logic [13:0] waddr,
    output logic [7:0] output_data,
    input [6:0] V0,
    input [6:0] H0,
    input [4:0] SW,
    input [4:0] SH,
    input [5:0] TW,
    input [5:0] TH,
    output logic DONE
);

parameter  IDLE=5'd0,PRE_PROCESS=5'd1,DELTA_X=5'd2,DELTA_Y=5'd3,IN16=5'd4,
           JUDGE=5'd5,Y0_ST=5'd6,Y1_ST=5'd7,Y2_ST=5'd8,Y3_ST=5'd9,X_ST=5'd10,
           Y_ST=5'd11,WRITE=5'd12,IN4=5'd13,DONE_ST=5'd14;
           
reg [4:0] state,next_state,cnt;
reg [6:0] q_x, q_y;
reg [7:0] win [0:15],inter [0:3],out_reg,cal_p_n1,cal_p_0,cal_p_1,
          cal_p_2,cal_result;
reg [17:0] p_x_delta, p_y_delta,cal_x_fp;
reg [24:0] p_x, p_y;        
    
wire x_match, y_match;
wire [24:0] x_add_delta, y_add_delta;
wire x_match_write, y_match_write;
wire x_jump_IN4;

wire [5:0] div_a=(state==DELTA_X)?SW-'d1:SH-'d1;        
wire [23:0] div_a_temp=div_a << 18;         
wire [5:0] div_b=(state==DELTA_X)?TW-'d1:TH-'d1;
wire [23:0] div_result=div_a_temp / div_b; 


assign DONE=state==DONE_ST;
assign ird='b1;
      
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        state<=IDLE;
        cnt<=5'd0;  
    end
    else begin
        state<=next_state;
        cnt<=(state!=next_state)?5'd0:cnt+5'd1;
    end
end

always @(*) begin
    case (state)
        IDLE:next_state=(enable)?PRE_PROCESS:IDLE;
        PRE_PROCESS:next_state=DELTA_X;
        DELTA_X:next_state=(cnt==5'd5)?DELTA_Y:DELTA_X;
        DELTA_Y:next_state=(cnt==5'd5)?IN16:DELTA_Y;
        IN16:next_state=(cnt==5'd16)?JUDGE:IN16 ;         
        JUDGE:next_state=(x_match && y_match)?WRITE:(y_match)?Y_ST:(x_match)?X_ST:Y0_ST;
        Y0_ST:next_state=Y1_ST;       
        Y1_ST:next_state=Y2_ST;       
        Y2_ST:next_state=Y3_ST;       
        Y3_ST:next_state=X_ST;        
        X_ST:next_state=WRITE;        
        Y_ST:next_state=WRITE;        
        WRITE:next_state=(q_y==TH-1'd1 && q_x==TW-1'd1)?DONE_ST:(q_x==TW-1'd1)?IN16:(x_jump_IN4)?IN4:JUDGE;
        IN4:next_state=(cnt==5'd4)?JUDGE:IN4;         
        DONE_ST:next_state=IDLE;
        default:next_state=IDLE;
    endcase
end 

always @(*) begin
    case (state)
        Y0_ST:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=win[0];  //(0,0)
            cal_p_0=win[1]; //(0,1)
            cal_p_1=win[2]; //(0,2)
            cal_p_2=win[3]; //(0,3)
        end 
        Y1_ST:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=win[4];  //(1,0)
            cal_p_0=win[5]; //(1,1)
            cal_p_1=win[6]; //(1,2)
            cal_p_2=win[7]; //(1,3)
        end 
        Y2_ST:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=win[8];  //(2,0)
            cal_p_0=win[9]; //(2,1)
            cal_p_1=win[10]; //(2,2)
            cal_p_2=win[11]; //(2,3)
        end 
        Y3_ST:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=win[12];  //(3,0)
            cal_p_0=win[13]; //(3,1)
            cal_p_1=win[14]; //(3,2)
            cal_p_2=win[15]; //(3,3)
        end 
        X_ST:begin
            cal_x_fp=p_y[17:0];
            cal_p_n1=inter[0];  
            cal_p_0=inter[1];
            cal_p_1=inter[2];
            cal_p_2=inter[3];
        end 
        Y_ST:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=inter[0];  
            cal_p_0=inter[1];
            cal_p_1=inter[2];
            cal_p_2=inter[3];
        end 
        default:begin
            cal_x_fp=p_x[17:0];
            cal_p_n1=18'd0;
            cal_p_0=18'd0;
            cal_p_1=18'd0;
            cal_p_2=18'd0;
        end 
    endcase
end

always @(*) begin
    case (state)
        IN16:begin
            we=1'b0;
            output_data=8'd0;
            waddr=14'd0;
            case (cnt)
               5'd0:iaddr=(((p_x[24:18]-2'd1)<<6)+((p_x[24:18]-2'd1)<<5)+((p_x[24:18]-2'd1)<<2))+((p_y[24:18]-2'd1));
               5'd1:iaddr=(((p_x[24:18]-2'd0)<<6)+((p_x[24:18]-2'd0)<<5)+((p_x[24:18]-2'd0)<<2))+((p_y[24:18]-2'd1));
               5'd2:iaddr=(((p_x[24:18]+2'd1)<<6)+((p_x[24:18]+2'd1)<<5)+((p_x[24:18]+2'd1)<<2))+((p_y[24:18]-2'd1));
               5'd3:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]-2'd1));
               5'd4:iaddr=(((p_x[24:18]-2'd1)<<6)+((p_x[24:18]-2'd1)<<5)+((p_x[24:18]-2'd1)<<2))+((p_y[24:18]+2'd0));
               5'd5:iaddr=(((p_x[24:18]-2'd0)<<6)+((p_x[24:18]-2'd0)<<5)+((p_x[24:18]-2'd0)<<2))+((p_y[24:18]+2'd0));
               5'd6:iaddr=(((p_x[24:18]+2'd1)<<6)+((p_x[24:18]+2'd1)<<5)+((p_x[24:18]+2'd1)<<2))+((p_y[24:18]+2'd0));
               5'd7:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd0));
               5'd8:iaddr=(((p_x[24:18]-2'd1)<<6)+((p_x[24:18]-2'd1)<<5)+((p_x[24:18]-2'd1)<<2))+((p_y[24:18]+2'd1));
               5'd9:iaddr=(((p_x[24:18]-2'd0)<<6)+((p_x[24:18]-2'd0)<<5)+((p_x[24:18]-2'd0)<<2))+((p_y[24:18]+2'd1));
               5'd10:iaddr=(((p_x[24:18]+2'd1)<<6)+((p_x[24:18]+2'd1)<<5)+((p_x[24:18]+2'd1)<<2))+((p_y[24:18]+2'd1));
               5'd11:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd1));
               5'd12:iaddr=(((p_x[24:18]-2'd1)<<6)+((p_x[24:18]-2'd1)<<5)+((p_x[24:18]-2'd1)<<2))+((p_y[24:18]+2'd2));
               5'd13:iaddr=(((p_x[24:18]-2'd0)<<6)+((p_x[24:18]-2'd0)<<5)+((p_x[24:18]-2'd0)<<2))+((p_y[24:18]+2'd2));
               5'd14:iaddr=(((p_x[24:18]+2'd1)<<6)+((p_x[24:18]+2'd1)<<5)+((p_x[24:18]+2'd1)<<2))+((p_y[24:18]+2'd2));
               5'd15:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd2));
               default:iaddr=14'd0;
            endcase
        end
        IN4:begin
            we=1'b0;
            output_data=8'd0;
            waddr=14'd0;
            case (cnt)
               5'd0:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]-2'd1));
               5'd1:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd0));
               5'd2:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd1));
               5'd3:iaddr=(((p_x[24:18]+2'd2)<<6)+((p_x[24:18]+2'd2)<<5)+((p_x[24:18]+2'd2)<<2))+((p_y[24:18]+2'd2));
                default:iaddr=14'd0;
            endcase
        end
        WRITE:begin
            iaddr=14'd0;
            we=1'b1;
            output_data=out_reg;
            waddr=q_x+q_y*TW;
        end
        default:begin
            output_data=8'd0;
            we=1'b0;
            iaddr=14'd0;
            waddr=14'd0;
        end 
    endcase
end


wire signed [12:0] a, b, c, d;   
assign a=- $signed({1'b0,cal_p_n1})+$signed({1'b0,cal_p_0})+$signed({1'b0,cal_p_0,1'b0}) - $signed({1'b0,cal_p_1}) - $signed({1'b0,cal_p_1,1'b0})+$signed({1'b0,cal_p_2});
assign b=$signed({1'b0,cal_p_n1,1'b0}) - $signed({1'b0,cal_p_0}) - $signed({1'b0,cal_p_0,2'b0})+$signed({1'b0,cal_p_1,2'b0}) - $signed({1'b0,cal_p_2});
assign c=- $signed({1'b0,cal_p_n1})+$signed({1'b0,cal_p_1});
assign d=$signed({1'b0,cal_p_0,1'b0});
                
wire [17:0] x3, x2, x1;      
wire [35:0] x2_temp,x3_temp;
assign x1=cal_x_fp;
assign x2_temp=x1 * cal_x_fp;
assign x2=x2_temp[35:18];
assign x3_temp=x2 * cal_x_fp;
assign x3=x3_temp[35:18];
wire signed [32:0] result_ext, ax, bx, cx, dx;     

assign ax=$signed(a) * $signed({1'b0,x3});
assign bx=$signed(b) * $signed({1'b0,x2});
assign cx=$signed(c) * $signed({1'b0,x1});
assign dx=$signed({d,18'd0});
assign result_ext=$signed(ax)+$signed(bx)+$signed(cx)+$signed(dx);
assign cal_result=(result_ext[32])?8'd0:(result_ext[32:19] > $signed(14'd255))?'d255:result_ext[26:19]+result_ext[18];   

          
//wires
assign x_match=(p_x[17:13]==5'd0)||(p_x[17:13]==5'b11111);
assign y_match=(p_y[17:13]==5'd0)||(p_y[17:13]==5'b11111);
assign x_add_delta=p_x+p_x_delta;
assign y_add_delta=p_y+p_y_delta;
assign x_match_write=(x_add_delta[17:13]==5'd0)|| (x_add_delta[17:13]==5'b11111);
assign y_match_write=(y_add_delta[17:13]==5'd0)||(y_add_delta[17:13]==5'b11111);
assign x_jump_IN4=x_match_write||(x_add_delta[24:18] > p_x[24:18]);

integer i1;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        for (i1=0; i1<16; i1=i1+1) begin
            win[i1]<=8'd0;
        end
        for (i1=0; i1<4; i1=i1+1) begin
            inter[i1]<=8'd0;
        end
        out_reg<=8'd0;
        p_x_delta<=18'd0;
        p_y_delta<=18'd0;
        p_x<=25'd0;
        p_y<=25'd0;
        q_x<=25'd0;
        q_y<=25'd0;
    end
    else begin
        case (state)
            PRE_PROCESS:begin
                p_x<={H0,18'd0};
                p_y<={V0,18'd0};
                q_x<=7'd0;
                q_y<=7'd0;
            end
            
            DELTA_X:p_x_delta<=div_result;
            DELTA_Y:p_y_delta<=div_result;
                
            
            IN16:begin
                case (cnt)
                   5'd1:win[00]<=input_data;
                   5'd2:win[01]<=input_data;
                   5'd3:win[02]<=input_data;
                   5'd4:win[03]<=input_data;
                   5'd5:win[04]<=input_data;
                   5'd6:win[05]<=input_data;
                   5'd7:win[06]<=input_data;
                   5'd8:win[07]<=input_data;
                   5'd9:win[08]<=input_data;
                   5'd10:win[09]<=input_data;
                   5'd11:win[10]<=input_data;
                   5'd12:win[11]<=input_data;
                   5'd13:win[12]<=input_data;
                   5'd14:win[13]<=input_data;
                   5'd15:win[14]<=input_data;
                   5'd16:win[15]<=input_data;
                endcase
            end 
            JUDGE:begin
                if (next_state==WRITE) begin
                    out_reg<=win[5];
                end
                if(next_state==Y_ST) begin
                    inter[0]<=win[4];
                    inter[1]<=win[5];
                    inter[2]<=win[6];
                    inter[3]<=win[7];
                end
                else if(next_state==X_ST) begin
                    inter[0]<=win[1];
                    inter[1]<=win[5];
                    inter[2]<=win[9];
                    inter[3]<=win[13];
                end
            end
            Y0_ST:inter[0]<=cal_result;    
            Y1_ST:inter[1]<=cal_result;
            Y2_ST:inter[2]<=cal_result;
            Y3_ST:inter[3]<=cal_result;
            X_ST:out_reg<=cal_result;
            Y_ST: out_reg<=cal_result;

            WRITE:begin
                if (q_x==(TW-'d1)) begin
                    p_x<={H0,{18'd0}};
                    q_x<='d0;
                    if (y_match_write) begin
                        p_y[24:18]<=y_add_delta[24:18]+y_add_delta[17];
                        p_y[17:0]<=25'd0;                           
                    end
                    else begin
                        p_y<=y_add_delta;
                    end
                    q_y<=q_y+'d1;
                end
                else if (x_jump_IN4) begin
                    if (x_match_write) begin
                        p_x[24:18]<=x_add_delta[24:18]+x_add_delta[17];
                        p_x[17:0]<=25'd0;                           
                    end
                    else begin
                        p_x<=x_add_delta;
                    end
                    q_x<=q_x +'d1;
                end
                else begin
                    p_x<=x_add_delta;
                    q_x<=q_x +'d1;
                end
                
                if (x_jump_IN4) begin
                    win[00]<=win [01];
                    win[01]<=win [02];
                    win[02]<=win [03];
                    win[04]<=win [05];
                    win[05]<=win [06];
                    win[06]<=win [07];
                    win[08]<=win [09];
                    win[09]<=win [10];
                    win[10]<=win [11];
                    win[12]<=win [13];
                    win[13]<=win [14];
                    win[14]<=win [15];
                end
            end
            IN4:begin
                case (cnt)
                   5'd1:win[03]<=input_data;     
                   5'd2:win[07]<=input_data;
                   5'd3:win[11]<=input_data;
                   5'd4:win[15]<=input_data;
                endcase
            end
        endcase
    end
end

endmodule

