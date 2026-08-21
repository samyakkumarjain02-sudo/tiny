`timescale 1ns/1ps

module tb_morse_codec;

    // ------------------------------------------------------------
    // Simulation timing
    // ------------------------------------------------------------

    localparam HUMAN_TICKS   = 3;
    localparam MACHINE_TICKS = 1;


    // ------------------------------------------------------------
    // Common signals
    // ------------------------------------------------------------

    reg clk;
    reg rst_n;
    reg ena;


    // ============================================================
    // ENCODER
    // ============================================================

    reg  [7:0] enc_ui;
    reg  [7:0] enc_uio_in;

    wire [7:0] enc_uo;
    wire [7:0] enc_uio_out;
    wire [7:0] enc_uio_oe;


    // ============================================================
    // DECODER
    // ============================================================

    reg  [7:0] dec_ui;
    reg  [7:0] dec_uio_in;

    wire [7:0] dec_uo;
    wire [7:0] dec_uio_out;
    wire [7:0] dec_uio_oe;


    // ------------------------------------------------------------
    // Morse connection between encoder and decoder
    // ------------------------------------------------------------

    always @(*) begin

        dec_uio_in[0] = enc_uio_out[0];

    end


    // ============================================================
    // ENCODER DUT
    // ============================================================

    tt_um_morse_codec #(
        .HUMAN_TICKS(HUMAN_TICKS),
        .MACHINE_TICKS(MACHINE_TICKS)
    ) encoder (
        .clk     (clk),
        .rst_n   (rst_n),
        .ena     (ena),

        .ui_in   (enc_ui),
        .uo_out  (enc_uo),

        .uio_in  (enc_uio_in),
        .uio_out (enc_uio_out),
        .uio_oe  (enc_uio_oe)
    );


    // ============================================================
    // DECODER DUT
    // ============================================================

    tt_um_morse_codec #(
        .HUMAN_TICKS(HUMAN_TICKS),
        .MACHINE_TICKS(MACHINE_TICKS)
    ) decoder (
        .clk     (clk),
        .rst_n   (rst_n),
        .ena     (ena),

        .ui_in   (dec_ui),
        .uo_out  (dec_uo),

        .uio_in  (dec_uio_in),
        .uio_out (dec_uio_out),
        .uio_oe  (dec_uio_oe)
    );


    // ============================================================
    // CLOCK
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // RESET
    // ============================================================

    task reset_dut;

        begin

            rst_n = 0;

            #50;

            rst_n = 1;

            #20;

        end

    endtask


    // ============================================================
    // TRANSMIT ONE ASCII CHARACTER
    // ============================================================

    task transmit_ascii;

        input [6:0] character;

        begin

            enc_ui[6:0] = character;

            // Start pulse
            enc_uio_in[2] = 1;

            @(posedge clk);

            enc_uio_in[2] = 0;

        end

    endtask


    // ============================================================
    // WAIT FOR DECODED ASCII
    // ============================================================

    task wait_for_ascii;

        input [6:0] expected;

        integer timeout;

        begin

            timeout = 0;

            while (!dec_uo[7] && timeout < 1000) begin

                @(posedge clk);

                timeout = timeout + 1;

            end


            if (timeout >= 1000) begin

                $display("ERROR: Decoder timeout");

            end

            else if (dec_uo[6:0] == expected) begin

                $display(
                    "PASS: Received ASCII = %c",
                    expected
                );

            end

            else begin

                $display(
                    "FAIL: Expected %c, Received %c",
                    expected,
                    dec_uo[6:0]
                );

            end

        end

    endtask


    // ============================================================
    // HUMAN MODE TEST
    // ============================================================

    task test_human_mode;

        begin

            $display("");
            $display("--------------------------------");
            $display(" HUMAN MODE TEST");
            $display("--------------------------------");


            // Human mode
            enc_ui[7] = 0;
            dec_ui[7] = 0;


            // Encoder
            enc_uio_in[1] = 1;

            // Decoder
            dec_uio_in[1] = 0;


            // Test A = .-
            $display("Sending A ...");

            transmit_ascii("A");

            wait_for_ascii("A");


            // Test S = ...
            $display("Sending S ...");

            transmit_ascii("S");

            wait_for_ascii("S");


            // Test O = ---
            $display("Sending O ...");

            transmit_ascii("O");

            wait_for_ascii("O");


            $display("Human mode test complete.");

        end

    endtask


    // ============================================================
    // MACHINE MODE TEST
    // ============================================================

    task test_machine_mode;

        begin

            $display("");
            $display("--------------------------------");
            $display(" MACHINE MODE TEST");
            $display("--------------------------------");


            // Machine mode
            enc_ui[7] = 1;
            dec_ui[7] = 1;


            // Encoder
            enc_uio_in[1] = 1;

            // Decoder
            dec_uio_in[1] = 0;


            // Test H
            $display("Sending H ...");

            transmit_ascii("H");

            wait_for_ascii("H");


            // Test E
            $display("Sending E ...");

            transmit_ascii("E");

            wait_for_ascii("E");


            // Test L
            $display("Sending L ...");

            transmit_ascii("L");

            wait_for_ascii("L");


            // Test L
            $display("Sending L ...");

            transmit_ascii("L");

            wait_for_ascii("L");


            // Test O
            $display("Sending O ...");

            transmit_ascii("O");

            wait_for_ascii("O");


            $display("Machine mode test complete.");

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // Initial values

        clk = 0;

        rst_n = 0;

        ena = 1;


        enc_ui = 0;
        dec_ui = 0;

        enc_uio_in = 0;
        dec_uio_in = 0;


        // Reset

        reset_dut();


        // Human mode

        test_human_mode();


        // Reset between modes

        reset_dut();


        // Machine mode

        test_machine_mode();


        // Finish

        $display("");
        $display("--------------------------------");
        $display(" ALL TESTS COMPLETE");
        $display("--------------------------------");

        #100;

        $finish;

    end

endmodule
