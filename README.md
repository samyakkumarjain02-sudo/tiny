![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# A Binary-Tree-Based Dual-Mode Morse Communication Engine with Pulse-Duration Encoding

Tiny Tapeout submission, SkyWater 130nm

- **Read the full project documentation**
- **Architecture and design documentation**
- **RTL simulation and verification results**

## What is this?

This project implements a compact dual-mode Morse Code Encoder/Decoder in RTL using a binary-tree architecture and pulse-duration encoding.

The design supports two modes. Human Mode uses standard Morse timing with timing tolerance for variations in human-generated signals, while Machine Mode uses shorter pulse durations for high-speed machine-to-machine communication.

The same chip can operate as a transmitter or receiver. ASCII data is converted to timed Morse pulses for transmission, and received Morse pulses are measured and decoded back into ASCII. Two identical chips can communicate through a single bidirectional Morse channel.

## Design Summary
- Top module: tt_um_samyak_morse_codec
- Technology: SkyWater 130nm
- Clock: 50 MHz
- Tile: 1×1
- Architecture: Binary-tree based
- Interface: 7-bit bidirectional ASCII + 1-bit bidirectional Morse
- Modes: Human and Machine
- Encoding: ASCII → Morse
- Decoding: Morse → ASCII
- Signaling: Pulse duration
- Characters: A–Z
- Verification: RTL simulation, synthesis and STA
  
## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.


## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
