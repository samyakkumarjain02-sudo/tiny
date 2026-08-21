module tt_um_morse_codec #(
    parameter integer HUMAN_TICKS   = 3_000_000, // 60 ms @ 50 MHz = 20 WPM
    parameter integer MACHINE_TICKS = 2          // Optimize using STA
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,

    input  wire [7:0] ui_in,
    output reg  [7:0] uo_out,

    input  wire [7:0] uio_in,
    output reg  [7:0] uio_out,
    output reg  [7:0] uio_oe
);

    // ------------------------------------------------------------
    // Pin assignment
    //
    // ui_in[6:0] = ASCII input
    // ui_in[7]   = mode
    //              0 = Human mode
    //              1 = Machine mode
    //
    // uio[0]     = bidirectional Morse channel
    // uio[1]     = TX/RX control
    //              1 = TX
    //              0 = RX
    // uio[2]     = start pulse
    //
    // uo_out[6:0] = decoded ASCII
    // uo_out[7]   = valid
    // ------------------------------------------------------------

    wire mode_machine = ui_in[7];
    wire [6:0] ascii_in = ui_in[6:0];

    wire tx_mode = uio_in[1];
    wire start   = uio_in[2];

    wire morse_in = uio_in[0];

    wire [31:0] TICKS =
        mode_machine ? MACHINE_TICKS : HUMAN_TICKS;


    // ============================================================
    // OUTPUT / STATUS
    // ============================================================

    reg [6:0] ascii_out_reg;
    reg       valid_reg;
    reg       error_reg;

    always @(*) begin

        uo_out = 8'b0;

        uo_out[6:0] = ascii_out_reg;
        uo_out[7]   = valid_reg;

    end


    // ============================================================
    // BIDIRECTIONAL MORSE PIN
    // ============================================================

    reg morse_out_reg;

    always @(*) begin

        uio_out = 8'b0;
        uio_oe  = 8'b0;

        if (tx_mode) begin
            uio_out[0] = morse_out_reg;
            uio_oe[0]  = 1'b1;
        end

    end


    // ============================================================
    // MORSE TREE
    //
    // Binary heap representation:
    //
    //              ROOT
    //             /    \
    //            E      T
    //           / \    / \
    //          I   A  N   M
    //
    // DOT  = LEFT
    // DASH = RIGHT
    //
    // Node numbers:
    //
    // E=2  T=3
    // I=4  A=5  N=6  M=7
    // S=8  U=9  R=10 W=11
    // D=12 K=13 G=14 O=15
    // H=16 V=17 F=18
    // L=20 P=22 J=23
    // B=24 X=25 C=26 Y=27
    // Z=28 Q=29
    // ============================================================


    // ------------------------------------------------------------
    // ASCII -> Morse tree node
    // ------------------------------------------------------------

    function [4:0] ascii_to_node;

        input [6:0] ascii;

        begin

            case (ascii)

                "A": ascii_to_node = 5'd5;
                "B": ascii_to_node = 5'd24;
                "C": ascii_to_node = 5'd26;
                "D": ascii_to_node = 5'd12;
                "E": ascii_to_node = 5'd2;
                "F": ascii_to_node = 5'd18;
                "G": ascii_to_node = 5'd14;
                "H": ascii_to_node = 5'd16;
                "I": ascii_to_node = 5'd4;
                "J": ascii_to_node = 5'd23;
                "K": ascii_to_node = 5'd13;
                "L": ascii_to_node = 5'd20;
                "M": ascii_to_node = 5'd7;
                "N": ascii_to_node = 5'd6;
                "O": ascii_to_node = 5'd15;
                "P": ascii_to_node = 5'd22;
                "Q": ascii_to_node = 5'd29;
                "R": ascii_to_node = 5'd10;
                "S": ascii_to_node = 5'd8;
                "T": ascii_to_node = 5'd3;
                "U": ascii_to_node = 5'd9;
                "V": ascii_to_node = 5'd17;
                "W": ascii_to_node = 5'd11;
                "X": ascii_to_node = 5'd25;
                "Y": ascii_to_node = 5'd27;
                "Z": ascii_to_node = 5'd28;

                default:
                    ascii_to_node = 5'd0;

            endcase

        end

    endfunction


    // ------------------------------------------------------------
    // Morse tree node -> ASCII
    // ------------------------------------------------------------

    function [6:0] node_to_ascii;

        input [4:0] node;

        begin

            case (node)

                5'd2:  node_to_ascii = "E";
                5'd3:  node_to_ascii = "T";

                5'd4:  node_to_ascii = "I";
                5'd5:  node_to_ascii = "A";
                5'd6:  node_to_ascii = "N";
                5'd7:  node_to_ascii = "M";

                5'd8:  node_to_ascii = "S";
                5'd9:  node_to_ascii = "U";
                5'd10: node_to_ascii = "R";
                5'd11: node_to_ascii = "W";

                5'd12: node_to_ascii = "D";
                5'd13: node_to_ascii = "K";
                5'd14: node_to_ascii = "G";
                5'd15: node_to_ascii = "O";

                5'd16: node_to_ascii = "H";
                5'd17: node_to_ascii = "V";
                5'd18: node_to_ascii = "F";

                5'd20: node_to_ascii = "L";

                5'd22: node_to_ascii = "P";
                5'd23: node_to_ascii = "J";

                5'd24: node_to_ascii = "B";
                5'd25: node_to_ascii = "X";
                5'd26: node_to_ascii = "C";
                5'd27: node_to_ascii = "Y";
                5'd28: node_to_ascii = "Z";
                5'd29: node_to_ascii = "Q";

                default:
                    node_to_ascii = 7'b0;

            endcase

        end

    endfunction


    // ------------------------------------------------------------
    // Return Morse tree depth
    // ------------------------------------------------------------

    function [3:0] node_depth;

        input [4:0] node;

        begin

            if (node < 2)
                node_depth = 0;
            else if (node < 4)
                node_depth = 1;
            else if (node < 8)
                node_depth = 2;
            else if (node < 16)
                node_depth = 3;
            else
                node_depth = 4;

        end

    endfunction


    // ============================================================
    // ENCODER
    // ============================================================

    reg [4:0] enc_node;
    reg [3:0] enc_pos;

    reg [31:0] enc_timer;

    reg [2:0] enc_state;

    localparam ENC_IDLE = 3'd0;
    localparam ENC_PULSE = 3'd1;
    localparam ENC_EGAP = 3'd2;
    localparam ENC_CGAP = 3'd3;

    wire [4:0] ascii_node = ascii_to_node(ascii_in);

    wire [3:0] ascii_depth = node_depth(enc_node);


    // ------------------------------------------------------------
    // Encoder
    // ------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            enc_node     <= 0;
            enc_pos      <= 0;
            enc_timer    <= 0;
            enc_state    <= ENC_IDLE;
            morse_out_reg <= 0;

        end

        else if (ena && tx_mode) begin

            case (enc_state)

                ENC_IDLE: begin

                    morse_out_reg <= 0;
                    enc_timer     <= 0;

                    if (start && ascii_node != 0) begin

                        enc_node <= ascii_node;
                        enc_pos  <= 0;

                        enc_state <= ENC_PULSE;

                    end

                end


                ENC_PULSE: begin

                    /*
                     * Extract path bit from tree node.
                     * 0 = DOT
                     * 1 = DASH
                     */

                    if (
                        enc_node[
                            (node_depth(enc_node)-1)-enc_pos
                        ]
                    ) begin

                        // DASH = 3T

                        morse_out_reg <= 1;

                        if (enc_timer >= (3*TICKS)-1) begin

                            enc_timer     <= 0;
                            morse_out_reg <= 0;
                            enc_state     <= ENC_EGAP;

                        end
                        else begin

                            enc_timer <= enc_timer + 1'b1;

                        end

                    end

                    else begin

                        // DOT = 1T

                        morse_out_reg <= 1;

                        if (enc_timer >= TICKS-1) begin

                            enc_timer     <= 0;
                            morse_out_reg <= 0;
                            enc_state     <= ENC_EGAP;

                        end
                        else begin

                            enc_timer <= enc_timer + 1'b1;

                        end

                    end

                end


                ENC_EGAP: begin

                    // Gap between Morse elements = 1T

                    morse_out_reg <= 0;

                    if (enc_timer >= TICKS-1) begin

                        enc_timer <= 0;

                        if (enc_pos + 1 >= node_depth(enc_node)) begin

                            enc_state <= ENC_CGAP;

                        end
                        else begin

                            enc_pos <= enc_pos + 1'b1;
                            enc_state <= ENC_PULSE;

                        end

                    end
                    else begin

                        enc_timer <= enc_timer + 1'b1;

                    end

                end


                ENC_CGAP: begin

                    // Character gap = 3T

                    morse_out_reg <= 0;

                    if (enc_timer >= (3*TICKS)-1) begin

                        enc_timer <= 0;
                        enc_state <= ENC_IDLE;

                    end
                    else begin

                        enc_timer <= enc_timer + 1'b1;

                    end

                end


                default:
                    enc_state <= ENC_IDLE;

            endcase

        end

    end


    // ============================================================
    // DECODER
    // ============================================================

    reg [4:0] dec_node;

    reg [31:0] pulse_timer;
    reg [31:0] gap_timer;

    reg previous_morse;

    reg character_done;
    reg word_done;


    // ------------------------------------------------------------
    // Decoder
    // ------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            dec_node       <= 5'd1;

            pulse_timer    <= 0;
            gap_timer      <= 0;

            previous_morse <= 0;

            character_done <= 0;
            word_done      <= 0;

            ascii_out_reg  <= 0;

            valid_reg      <= 0;
            error_reg      <= 0;

        end

        else if (ena && !tx_mode) begin

            valid_reg <= 0;

            // ----------------------------------------------------
            // HIGH pulse
            // ----------------------------------------------------

            if (morse_in) begin

                pulse_timer <= pulse_timer + 1'b1;
                gap_timer   <= 0;

                character_done <= 0;
                word_done      <= 0;

            end


            // ----------------------------------------------------
            // Falling edge
            // ----------------------------------------------------

            else if (previous_morse) begin

                // DOT
                if (pulse_timer < (2*TICKS)) begin

                    if ((dec_node << 1) <= 29)
                        dec_node <= dec_node << 1;
                    else
                        error_reg <= 1;

                end

                // DASH
                else if (pulse_timer < (5*TICKS)) begin

                    if (((dec_node << 1) + 1) <= 29)
                        dec_node <= (dec_node << 1) + 1'b1;
                    else
                        error_reg <= 1;

                end

                // Invalid pulse
                else begin

                    error_reg <= 1;
                    dec_node  <= 1;

                end

                pulse_timer <= 0;

            end


            // ----------------------------------------------------
            // LOW gap
            // ----------------------------------------------------

            else begin

                if (gap_timer < (7*TICKS))
                    gap_timer <= gap_timer + 1'b1;


                // Character gap = 3T

                if (
                    gap_timer >= (3*TICKS)-1 &&
                    !character_done &&
                    dec_node != 1
                ) begin

                    ascii_out_reg <= node_to_ascii(dec_node);

                    valid_reg <= 1;

                    character_done <= 1;

                    dec_node <= 1;

                end


                // Word gap = 7T

                if (
                    gap_timer >= (7*TICKS)-1 &&
                    !word_done
                ) begin

                    ascii_out_reg <= " ";

                    valid_reg <= 1;

                    word_done <= 1;

                    dec_node <= 1;

                end

            end

            previous_morse <= morse_in;

        end

    end

endmodule

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
