`timescale 1ns/1ps
`default_nettype none

module tb;

    reg clk;
    reg rst_n;
    reg ena;

    // ------------------------------------------------------------
    // Control inputs
    // ui_in[0] = START / DATA_VALID
    // ui_in[1] = TX/RX
    //             1 = TX
    //             0 = RX
    // ui_in[2] = MODE
    //             0 = Human
    //             1 = Machine
    // ui_in[3] = ENABLE
    // ------------------------------------------------------------

    reg [7:0] ui_tx;
    reg [7:0] ui_rx;

    wire [7:0] uo_tx;
    wire [7:0] uo_rx;

    wire [7:0] uio_tx_out;
    wire [7:0] uio_rx_out;

    wire [7:0] uio_tx_oe;
    wire [7:0] uio_rx_oe;

    wire [7:0] uio_tx_in;
    wire [7:0] uio_rx_in;

    // ------------------------------------------------------------
    // Chip-to-chip Morse connection
    // ONLY uio[0] is connected between the two chips
    // ------------------------------------------------------------

    wire morse_line;

    assign morse_line =
            uio_tx_oe[0] ? uio_tx_out[0] :
            uio_rx_oe[0] ? uio_rx_out[0] :
            1'bz;

    // TX ASCII bus
    assign uio_tx_in[7:1] = 7'bz;

    // RX ASCII bus
    assign uio_rx_in[7:1] = 7'bz;

    // Morse input to both chips
    assign uio_tx_in[0] = morse_line;
    assign uio_rx_in[0] = morse_line;

    // ------------------------------------------------------------
    // CHIP A : Encoder / Transmitter
    // ------------------------------------------------------------

    tt_um_samyak_krish_morse_codec #(
        .HUMAN_TICKS(10),
        .MACHINE_TICKS(2),

        .HUMAN_DOT_MIN(7),
        .HUMAN_DOT_MAX(13),

        .HUMAN_DASH_MIN(22),
        .HUMAN_DASH_MAX(38),

        .HUMAN_GAP_SYM_MAX(13),
        .HUMAN_GAP_CHAR_MIN(14),
        .HUMAN_GAP_CHAR_MAX(20),
        .HUMAN_GAP_WORD_MIN(31)
    ) chip_tx (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),

        .ui_in(ui_tx),
        .uo_out(uo_tx),

        .uio_in(uio_tx_in),
        .uio_out(uio_tx_out),
        .uio_oe(uio_tx_oe)
    );

    // ------------------------------------------------------------
    // CHIP B : Decoder / Receiver
    // ------------------------------------------------------------

    tt_um_samyak_krish_morse_codec #(
        .HUMAN_TICKS(10),
        .MACHINE_TICKS(2),

        .HUMAN_DOT_MIN(7),
        .HUMAN_DOT_MAX(13),

        .HUMAN_DASH_MIN(22),
        .HUMAN_DASH_MAX(38),

        .HUMAN_GAP_SYM_MAX(13),
        .HUMAN_GAP_CHAR_MIN(14),
        .HUMAN_GAP_CHAR_MAX(20),
        .HUMAN_GAP_WORD_MIN(31)
    ) chip_rx (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),

        .ui_in(ui_rx),
        .uo_out(uo_rx),

        .uio_in(uio_rx_in),
        .uio_out(uio_rx_out),
        .uio_oe(uio_rx_oe)
    );

    // ------------------------------------------------------------
    // 50 MHz clock
    // ------------------------------------------------------------

    always #10 clk = ~clk;

    // ------------------------------------------------------------
    // Send one ASCII character to Encoder
    // ------------------------------------------------------------

    task send_ascii;
        input [6:0] ascii_char;

        begin
            ui_tx[7:1] = ascii_char;
            ui_tx[0]   = 1'b1;

            @(posedge clk);

            ui_tx[0] = 1'b0;

            $display("TX ASCII = %c", ascii_char);
        end
    endtask

    // ------------------------------------------------------------
    // Wait for decoded ASCII
    // ------------------------------------------------------------

    task wait_for_ascii;
        input [6:0] expected;

        begin
            wait (uo_rx[0] == 1'b1);

            if (chip_rx.decoded_ascii == expected)
                $display("PASS: RX ASCII = %c", expected);
            else
                $display("FAIL: Expected %c, Received %c",
                         expected,
                         chip_rx.decoded_ascii);

            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Configure TX / RX
    // ------------------------------------------------------------

    task configure_tx_rx;
        input machine;

        begin

            // CHIP A = TX
            ui_tx[1] = 1'b1;

            // CHIP B = RX
            ui_rx[1] = 1'b0;

            // Human / Machine
            ui_tx[2] = machine;
            ui_rx[2] = machine;

            // Enable
            ui_tx[3] = 1'b1;
            ui_rx[3] = 1'b1;

            ui_tx[0] = 1'b0;
            ui_rx[0] = 1'b0;

            repeat (2) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // HUMAN MODE TEST
    // ------------------------------------------------------------

    task human_mode_test;

        begin

            $display("");
            $display("==============================");
            $display(" HUMAN MODE TEST");
            $display("==============================");

            configure_tx_rx(1'b0);

            // S = ...
            send_ascii("S");
            wait_for_ascii("S");

            // O = ---
            send_ascii("O");
            wait_for_ascii("O");

            // S = ...
            send_ascii("S");
            wait_for_ascii("S");

            $display("HUMAN MODE TEST COMPLETE");

        end
    endtask

    // ------------------------------------------------------------
    // MACHINE MODE TEST
    // ------------------------------------------------------------

    task machine_mode_test;

        begin

            $display("");
            $display("==============================");
            $display(" MACHINE MODE TEST");
            $display("==============================");

            configure_tx_rx(1'b1);

            // A = .-
            send_ascii("A");
            wait_for_ascii("A");

            // B = -...
            send_ascii("B");
            wait_for_ascii("B");

            // C = -.-.
            send_ascii("C");
            wait_for_ascii("C");

            $display("MACHINE MODE TEST COMPLETE");

        end
    endtask

    // ------------------------------------------------------------
    // MULTIPLE CHARACTER TEST
    // ------------------------------------------------------------

    task multiple_character_test;

        begin

            $display("");
            $display("==============================");
            $display(" MULTIPLE CHARACTER TEST");
            $display("==============================");

            configure_tx_rx(1'b1);

            send_ascii("H");
            wait_for_ascii("H");

            send_ascii("I");
            wait_for_ascii("I");

            send_ascii("S");
            wait_for_ascii("S");

            $display("MULTIPLE CHARACTER TEST COMPLETE");

        end
    endtask

    // ------------------------------------------------------------
    // WORD GAP TEST
    // ------------------------------------------------------------

    task word_gap_test;

        begin

            $display("");
            $display("==============================");
            $display(" WORD GAP TEST");
            $display("==============================");

            configure_tx_rx(1'b1);

            // First word
            send_ascii("S");
            wait_for_ascii("S");

            // Send ASCII space
            send_ascii(7'd32);

            // Second word
            send_ascii("O");
            wait_for_ascii("O");

            $display("WORD GAP TEST COMPLETE");

        end
    endtask

    // ------------------------------------------------------------
    // MAIN TEST
    // ------------------------------------------------------------

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;
        ena = 1'b1;

        ui_tx = 8'b0;
        ui_rx = 8'b0;

        // Reset
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // Human Mode
        human_mode_test;

        // Machine Mode
        machine_mode_test;

        // Multiple characters
        multiple_character_test;

        // Word gap
        word_gap_test;

        $display("");
        $display("==============================");
        $display(" ALL TESTS COMPLETED");
        $display("==============================");

        #100;

        $finish;
    end

endmodule

`default_nettype wire
