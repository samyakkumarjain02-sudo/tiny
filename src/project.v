
`default_nettype none

module tt_um_samyak_morse_krish_codec #(
    parameter integer HUMAN_TICKS   = 3_000_000, // 60 ms @ 50 MHz
    parameter integer MACHINE_TICKS = 10,
    parameter integer HUMAN_DOT_MIN = 2_000_000,
    parameter integer HUMAN_DOT_MAX = 4_000_000,
    parameter integer HUMAN_DASH_MIN = 5_000_000,
    parameter integer HUMAN_DASH_MAX = 12_000_000,
    parameter integer HUMAN_GAP_SYM_MAX = 2_000_000,
    parameter integer HUMAN_GAP_CHAR_MIN = 2_000_001,
    parameter integer HUMAN_GAP_CHAR_MAX = 5_000_000,
    parameter integer HUMAN_GAP_WORD_MIN = 6_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);

    // ui_in[0] = START / DATA_VALID
    // ui_in[1] = TX/RX: 1=TX, 0=RX
    // ui_in[2] = MODE:   0=Human, 1=Machine
    // ui_in[3] = local enable
    // ui_in[7:4] reserved

    wire tx_mode = ui_in[1];
    wire machine_mode = ui_in[2];
    wire local_enable = ui_in[3];
    wire start = ui_in[0];

    reg [7:0] uo_r;
    reg [7:0] uio_out_r;
    reg [7:0] uio_oe_r;

    assign uo_out  = uo_r;
    assign uio_out = uio_out_r;
    assign uio_oe  = uio_oe_r;

    localparam [2:0] TX_IDLE      = 3'd0;
    localparam [2:0] TX_PULSE    = 3'd1;
    localparam [2:0] TX_SYMGAP   = 3'd2;
    localparam [2:0] TX_CHARGAP  = 3'd3;
    localparam [2:0] TX_WORDGAP  = 3'd4;

    reg [2:0] tx_state;
    reg [23:0] tx_count;
        reg [3:0] tx_code;
    reg [2:0] tx_len;
    reg [2:0] tx_pos;
    reg tx_last;
    reg tx_morse;
    reg start_d;
    reg error_flag;
    wire [6:0] tx_info = morse_info(uio_in[7:1]);

    function [6:0] morse_info;
        input [6:0] c;
        begin
            // {length, code}; code is left-aligned, DOT=0, DASH=1.
            case (c)
                "A": morse_info = {3'd2,4'b0100};
                "B": morse_info = {3'd4,4'b1000};
                "C": morse_info = {3'd4,4'b1010};
                "D": morse_info = {3'd3,4'b1000};
                "E": morse_info = {3'd1,4'b0000};
                "F": morse_info = {3'd4,4'b0010};
                "G": morse_info = {3'd3,4'b1100};
                "H": morse_info = {3'd4,4'b0000};
                "I": morse_info = {3'd2,4'b0000};
                "J": morse_info = {3'd4,4'b0111};
                "K": morse_info = {3'd3,4'b1010};
                "L": morse_info = {3'd4,4'b0100};
                "M": morse_info = {3'd2,4'b1100};
                "N": morse_info = {3'd2,4'b1000};
                "O": morse_info = {3'd3,4'b1110};
                "P": morse_info = {3'd4,4'b0110};
                "Q": morse_info = {3'd4,4'b1101};
                "R": morse_info = {3'd3,4'b0100};
                "S": morse_info = {3'd3,4'b0000};
                "T": morse_info = {3'd1,4'b1000};
                "U": morse_info = {3'd3,4'b0010};
                "V": morse_info = {3'd4,4'b0001};
                "W": morse_info = {3'd3,4'b0110};
                "X": morse_info = {3'd4,4'b1001};
                "Y": morse_info = {3'd4,4'b1011};
                "Z": morse_info = {3'd4,4'b1100};
                default: morse_info = 7'd0;
            endcase
        end
    endfunction

    function [23:0] unit_ticks;
        input mode;
        begin
            unit_ticks = mode ? MACHINE_TICKS : HUMAN_TICKS;
        end
    endfunction

    // ---------------- Encoder ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_count <= 0;
            tx_ascii <= 0;
            tx_code <= 0;
            tx_len <= 0;
            tx_pos <= 0;
            tx_last <= 0;
            tx_morse <= 1'b0;
            start_d <= 0;
            error_flag <= 1'b0;
        end else begin
            start_d <= start;

            if (!ena || !local_enable || !tx_mode) begin
                tx_state <= TX_IDLE;
                tx_count <= 0;
                tx_morse <= 1'b0;
            end else begin
                case (tx_state)
                    TX_IDLE: begin
                        tx_morse <= 1'b0;
                        tx_count <= 0;
                        if (start && !start_d) begin
                            if (uio_in[7:1] == 7'd32) begin
                                tx_state <= TX_WORDGAP;
                                tx_count <= 0;
                            end else begin
                                tx_len <= tx_info[6:4];
                                tx_code <= tx_info[3:0];
                                if (tx_info[6:4] != 0) begin
                                    tx_pos <= 0;
                                    tx_last <= (tx_info[6:4] == 1);
                                    tx_state <= TX_PULSE;
                                end else begin
                                    error_flag <= 1'b1;
                                end
                            end
                        end
                    end

                    TX_PULSE: begin
                        tx_morse <= 1'b1;
                        if (tx_count + 1 >= (tx_code[3-tx_pos] ? (3*unit_ticks(machine_mode)) : unit_ticks(machine_mode))) begin
                            tx_count <= 0;
                            tx_morse <= 1'b0;
                            if (tx_last)
                                tx_state <= TX_CHARGAP;
                            else
                                tx_state <= TX_SYMGAP;
                        end else begin
                            tx_count <= tx_count + 1;
                        end
                    end

                    TX_SYMGAP: begin
                        tx_morse <= 1'b0;
                        if (tx_count + 1 >= unit_ticks(machine_mode)) begin
                            tx_count <= 0;
                            tx_pos <= tx_pos + 1'b1;
                            tx_last <= (tx_pos + 1 >= tx_len - 1);
                            tx_state <= TX_PULSE;
                        end else tx_count <= tx_count + 1;
                    end

                    TX_CHARGAP: begin
                        tx_morse <= 1'b0;
                        if (tx_count + 1 >= (3*unit_ticks(machine_mode))) begin
                            tx_state <= TX_IDLE;
                            tx_count <= 0;
                        end else tx_count <= tx_count + 1;
                    end

                    TX_WORDGAP: begin
                        tx_morse <= 1'b0;
                        if (tx_count + 1 >= (7*unit_ticks(machine_mode))) begin
                            tx_state <= TX_IDLE;
                            tx_count <= 0;
                        end else tx_count <= tx_count + 1;
                    end

                    default: tx_state <= TX_IDLE;
                endcase
            end
        end
    end

    // ---------------- Decoder ----------------
    reg rx_prev;
    reg [23:0] high_count;
    reg [23:0] low_count;
    reg [5:0] tree_node;
    reg receiving_char;
    reg [6:0] decoded_ascii;
    reg valid_pulse;
    reg error_pulse;

    // Morse binary tree node mapping:
    // root=1, DOT=left(2*n), DASH=right(2*n+1).
    // Nodes 2..31 correspond to E,T,I,A,N,M,...,H/V/F/U...
    function [6:0] node_ascii;
        input [5:0] n;
        begin
            case (n)
                2: node_ascii="E"; 3: node_ascii="T";
                4: node_ascii="I"; 5: node_ascii="A";
                6: node_ascii="N"; 7: node_ascii="M";
                8: node_ascii="S"; 9: node_ascii="U";
                10: node_ascii="R"; 11: node_ascii="W";
                12: node_ascii="D"; 13: node_ascii="K";
                14: node_ascii="G"; 15: node_ascii="O";
                16: node_ascii="H"; 17: node_ascii="V";
                18: node_ascii="F"; 19: node_ascii=7'd0;
                20: node_ascii="L"; 21: node_ascii=7'd0;
                22: node_ascii="P"; 23: node_ascii="J";
                24: node_ascii="B"; 25: node_ascii="X";
                26: node_ascii="C"; 27: node_ascii="Y";
                28: node_ascii="Z"; 29: node_ascii="Q";
                default: node_ascii=7'd0;
            endcase
        end
    endfunction

    function [23:0] rx_dot_min;
        input mode;
        begin rx_dot_min = mode ? (MACHINE_TICKS/2) : HUMAN_DOT_MIN; end
    endfunction

    function [23:0] rx_dot_max;
        input mode;
        begin rx_dot_max = mode ? ((3*MACHINE_TICKS)/2) : HUMAN_DOT_MAX; end
    endfunction

    function [23:0] rx_dash_min;
        input mode;
        begin rx_dash_min = mode ? (2*MACHINE_TICKS) : HUMAN_DASH_MIN; end
    endfunction

    function [23:0] rx_dash_max;
        input mode;
        begin rx_dash_max = mode ? (4*MACHINE_TICKS) : HUMAN_DASH_MAX; end
    endfunction

    function [23:0] rx_char_min;
        input mode;
        begin rx_char_min = mode ? (2*MACHINE_TICKS) : HUMAN_GAP_CHAR_MIN; end
    endfunction

    function [23:0] rx_char_max;
        input mode;
        begin rx_char_max = mode ? (5*MACHINE_TICKS) : HUMAN_GAP_CHAR_MAX; end
    endfunction

    function [23:0] rx_word_min;
        input mode;
        begin rx_word_min = mode ? (6*MACHINE_TICKS) : HUMAN_GAP_WORD_MIN; end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_prev <= 1'b0;
            high_count <= 0;
            low_count <= 0;
            tree_node <= 1;
            receiving_char <= 1'b0;
            decoded_ascii <= 0;
            valid_pulse <= 1'b0;
            error_pulse <= 1'b0;
        end else begin
            valid_pulse <= 1'b0;
            error_pulse <= 1'b0;

            if (!ena || !local_enable || tx_mode) begin
                rx_prev <= 1'b0;
                high_count <= 0;
                low_count <= 0;
                tree_node <= 1;
                receiving_char <= 1'b0;
                end else begin
                rx_prev <= uio_in[0];

                if (uio_in[0]) begin
                    low_count <= 0;
                    high_count <= high_count + 1'b1;
                end else begin
                    if (rx_prev) begin
                        // Falling edge: classify the completed HIGH pulse.
                        if ((high_count >= rx_dot_min(machine_mode)) &&
                            (high_count <= rx_dot_max(machine_mode))) begin
                            tree_node <= tree_node << 1;
                            receiving_char <= 1'b1;
                                        end else if ((high_count >= rx_dash_min(machine_mode)) &&
                                     (high_count <= rx_dash_max(machine_mode))) begin
                            tree_node <= (tree_node << 1) | 1'b1;
                            receiving_char <= 1'b1;
                                        end else begin
                            error_pulse <= 1'b1;
                            tree_node <= 1;
                            receiving_char <= 1'b0;
                        end
                    end

                    high_count <= 0;
                    low_count <= low_count + 1'b1;

                    // A new pulse ends any pending word-gap interpretation.
                    if (rx_prev)
            
                    // First detect a word gap. If the character was already
                    // completed at the character-gap threshold, output space now.
                    if (gap_char_done &&
                        (low_count >= rx_word_min(machine_mode))) begin
                        decoded_ascii <= 7'd32;
                        valid_pulse <= 1'b1;
                                end
                    // Character gap: finish the current Morse character.
                    else if (receiving_char &&
                             (low_count >= rx_char_min(machine_mode))) begin
                        decoded_ascii <= node_ascii(tree_node);
                        if (node_ascii(tree_node) != 0) begin
                            valid_pulse <= 1'b1;
                        end else begin
                            error_pulse <= 1'b1;
                        end
                        tree_node <= 1;
                        receiving_char <= 1'b0;
                        gap_char_done <= 1'b1;
                    end
                end
            end
        end
    end

    // ---------------- Outputs / I/O direction ----------------
    always @(*) begin
        uio_out_r = 8'b0;
        uio_oe_r  = 8'b0;

        if (tx_mode) begin
            // TX: uio[7:1] are inputs, uio[0] drives Morse.
            uio_oe_r[0] = 1'b1;
            uio_out_r[0] = tx_morse;
        end else begin
            // RX: uio[7:1] drive decoded ASCII, uio[0] is input.
            uio_oe_r[7:1] = 7'b1111111;
            uio_out_r[7:1] = decoded_ascii;
        end

        if (!ena || !local_enable)
            uio_oe_r = 8'b0;
    end

    always @(*) begin
        uo_r = 8'b0;
        uo_r[0] = valid_pulse;
        uo_r[1] = error_flag | error_pulse;
    end

endmodule

`default_nettype wire
