# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_morse_codec(dut):
    dut._log.info("Starting Morse Verilog testbench")

    # tb_morse_codec has its own:
    # - clock
    # - reset
    # - TX/RX DUTs
    # - Human Mode tests
    # - Machine Mode tests
    # - chip-to-chip communication
    #
    # Just allow the Verilog testbench to run.
    await Timer(2, unit="us")

    dut._log.info("Morse Verilog testbench completed")
