`timescale 1ns/1ps
`default_nettype none

module tb_morse_codec;

    reg clk;
    reg rst_n;
    reg ena;

    // ui_in[0] = START / DATA_VALID
    // ui_in[1] = TX/RX: 1=TX, 0=RX
    // ui_in[2] = MODE:   0=Human, 1=Machine
    // ui_in[3] = ENABLE
    reg [7:0] ui_tx;
    reg [7:0] ui_rx;

    wire [7:0] uo_tx;
    wire [7:0] uo_rx;

    wire [7:0] uio_tx_out;
    wire [7:0] uio_rx_out;
    wire [7:0] uio_tx_oe;
    wire [7:0] uio_rx_oe;

    // Only the Morse pin is connected between the two chips.
    tri morse_wire;

    assign morse_wire =
        uio_tx_oe[0] ? uio_tx_out[0] : 1'bz;

    assign morse_wire =
        uio_rx_oe[0] ? uio_rx_out[0] : 1'bz;

    // TX chip receives its local ASCII data.
    wire [7:0] uio_tx_in = {ui_tx[7:1], morse_wire};

    // RX chip receives only Morse.
    wire [7:0] uio_rx_in = {7'b0, morse_wire};

    // ------------------------------------------------------------
    // TX CHIP
    // ------------------------------------------------------------

    tt_um_samyak_krish_morse_codec chip_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .ena     (ena),
        .ui_in   (ui_tx),
        .uo_out  (uo_tx),
        .uio_in  (uio_tx_in),
        .uio_out (uio_tx_out),
        .uio_oe  (uio_tx_oe)
    );

    // ------------------------------------------------------------
    // RX CHIP
    // ------------------------------------------------------------

    tt_um_samyak_krish_morse_codec chip_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .ena     (ena),
        .ui_in   (ui_rx),
        .uo_out  (uo_rx),
        .uio_in  (uio_rx_in),
        .uio_out (uio_rx_out),
        .uio_oe  (uio_rx_oe)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    // ------------------------------------------------------------
    // RESET
    // ------------------------------------------------------------

    task reset_dut;
        begin
            rst_n = 1'b0;

            repeat (10)
                @(posedge clk);

            rst_n = 1'b1;

            repeat (5)
                @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // CONFIGURE TX/RX
    // ------------------------------------------------------------

    task configure_link;
        input machine;
        begin

            // TX chip
            ui_tx[1] = 1'b1;
            ui_tx[2] = machine;
            ui_tx[3] = 1'b1;
            ui_tx[0] = 1'b0;

            // RX chip
            ui_rx[1] = 1'b0;
            ui_rx[2] = machine;
            ui_rx[3] = 1'b1;
            ui_rx[0] = 1'b0;

            repeat (5)
                @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // SEND ASCII CHARACTER
    // ------------------------------------------------------------

    task send_ascii;
        input [6:0] ascii_char;

        begin
            ui_tx[7:1] = ascii_char;

            // DATA_VALID pulse
            @(posedge clk);
            ui_tx[0] = 1'b1;

            @(posedge clk);
            ui_tx[0] = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // CHECK RECEIVED ASCII
    // ------------------------------------------------------------

    task check_ascii;
        input [6:0] expected;
        input integer timeout_cycles;

        integer i;
        reg found;

        begin

            found = 1'b0;

            for (i = 0; i < timeout_cycles; i = i + 1) begin

                @(posedge clk);

                if (uo_rx[0] === 1'b1) begin

                    found = 1'b1;

                    if (uio_rx_out[7:1] !== expected) begin

                        $display(
                            "FAIL: expected '%c', received '%c'",
                            expected,
                            uio_rx_out[7:1]
                        );

                        $fatal;
                    end

                    else begin

                        $display(
                            "PASS: '%c' received correctly",
                            expected
                        );

                    end

                    i = timeout_cycles;
                end
            end

            if (!found) begin

                $display(
                    "FAIL: timeout waiting for '%c'",
                    expected
                );

                $fatal;
            end

            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // MACHINE MODE TEST
    // ------------------------------------------------------------

    task test_machine_mode;

        begin

            $display("");
            $display("================================");
            $display(" MACHINE MODE");
            $display("================================");

            configure_link(1'b1);

            // S = ...
            send_ascii("S");
            check_ascii("S", 1000);

            // O = ---
            send_ascii("O");
            check_ascii("O", 1000);

            // S = ...
            send_ascii("S");
            check_ascii("S", 1000);

            // A = .-
            send_ascii("A");
            check_ascii("A", 1000);

            // Z = --..
            send_ascii("Z");
            check_ascii("Z", 1000);

            $display("Machine Mode PASS");

        end

    endtask

    // ------------------------------------------------------------
    // HUMAN MODE TEST
    // ------------------------------------------------------------

    task test_human_mode;

        begin

            $display("");
            $display("================================");
            $display(" HUMAN MODE");
            $display("================================");

            configure_link(1'b0);

            // E = .
            send_ascii("E");

            // Human timing is much slower.
            check_ascii("E", 5000000);

            $display("Human Mode PASS");

        end

    endtask

    // ------------------------------------------------------------
    // MAIN TEST
    // ------------------------------------------------------------

    initial begin

        clk   = 1'b0;
        rst_n = 1'b0;
        ena   = 1'b1;

        ui_tx = 8'b0;
        ui_rx = 8'b0;

        reset_dut;

        // Machine-mode end-to-end test
        test_machine_mode;

        // Human-mode end-to-end test
        test_human_mode;

        $display("");
        $display("================================");
        $display(" ALL MORSE TESTS PASSED");
        $display("================================");

        #100;

        $finish;

    end

endmodule

`default_nettype wire
