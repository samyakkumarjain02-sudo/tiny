
`timescale 1ns/1ps
`default_nettype none

module tb_morse_codec;

    reg clk = 0;
    reg rst_n = 0;
    reg ena = 1;

    reg [7:0] ui_tx = 0;
    reg [7:0] ui_rx = 0;

    wire [7:0] uo_tx, uo_rx;
    wire [7:0] uio_tx_out, uio_rx_out;
    wire [7:0] uio_tx_oe, uio_rx_oe;

    tri [7:0] tx_bus;
    tri [7:0] rx_bus;

    wire morse_wire;
    assign morse_wire = uio_tx_oe[0] ? uio_tx_out[0] : 1'bz;
    assign morse_wire = uio_rx_oe[0] ? uio_rx_out[0] : 1'bz;

    assign tx_bus[7:1] = uio_tx_oe[7:1] ? uio_tx_out[7:1] : 7'bz;
    assign rx_bus[7:1] = uio_rx_oe[7:1] ? uio_rx_out[7:1] : 7'bz;

    wire [7:0] uio_tx_in = {tx_bus[7:1], morse_wire};
    wire [7:0] uio_rx_in = {rx_bus[7:1], morse_wire};

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
    ) tx (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .ui_in(ui_tx), .uo_out(uo_tx),
        .uio_in(uio_tx_in), .uio_out(uio_tx_out), .uio_oe(uio_tx_oe)
    );

    tt_um_samyak_morse_codec #(
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
    ) rx (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .ui_in(ui_rx), .uo_out(uo_rx),
        .uio_in(uio_rx_in), .uio_out(uio_rx_out), .uio_oe(uio_rx_oe)
    );

    always #5 clk = ~clk;

    task send_char;
        input [6:0] c;
        begin
            ui_tx[7:1] = c;
            ui_tx[0] = 1'b1;
            @(posedge clk);
            ui_tx[0] = 1'b0;
            wait (tx.uio_oe[0] == 1'b0);
            repeat (2) @(posedge clk);
        end
    endtask

    task check_char;
        input [6:0] expected;
        begin
            wait (uo_rx[0] === 1'b1);
            if (rx.decoded_ascii === expected)
                $display("PASS: decoded %c", expected);
            else
                $display("FAIL: expected %c, got %c", expected, rx.decoded_ascii);
            @(posedge clk);
        end
    endtask

    task run_mode;
        input machine;
        input [8*5-1:0] label;
        begin
            $display("\n--- %s MODE ---", label);
            ui_tx[1] = 1'b1;
            ui_rx[1] = 1'b0;
            ui_tx[2] = machine;
            ui_rx[2] = machine;
            ui_tx[3] = 1'b1;
            ui_rx[3] = 1'b1;

            send_char("S");
            check_char("S");

            send_char("O");
            check_char("O");

            send_char("S");
            check_char("S");
        end
    endtask

    initial begin
        ui_tx[3] = 1;
        ui_rx[3] = 1;
        #20;
        rst_n = 1;
        #20;

        run_mode(1'b0, "HUMAN");
        run_mode(1'b1, "MACHINE");

        $display("\nAll requested basic encoder/decoder tests completed.");
        #50;
        $finish;
    end

endmodule

`default_nettype wire
