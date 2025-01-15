# Audio-Engines-ZX-Next

Audio engines for playing samples on the ZX Spectrum Next by Kev Brady / 9bitcolor.

## Overview

This project provides two different audio engines for playing 8-bit PCM samples on the ZX Spectrum Next:

1. Single Channel Engine
   - 1 channel of 8-bit PCM audio
   - 15.6KHz sampling rate
   - Uses the COPPER co-processor
   
2. Multi-Channel Engine
   - 4 channels of 8-bit PCM audio
   - 15.6KHz sampling rate
   - Uses CTC interrupts

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Features

- High-quality 8-bit PCM audio playback
- Choice between single-channel and multi-channel implementations
- Optimized for the ZX Spectrum Next hardware
- Sample rate of 15.6KHz for good audio quality

## Requirements

- ZX Spectrum Next hardware or emulator
- Compatible assembler for building (details to be added)

## Usage

See the MAIN.ASM file for usage instructions. Included is an example SNX file that you can load with the browser. COPAUDIO.SNX is the single channel engine and CTCAUDIO.SNX is the multi-channel engine and will play the same sample on all 4 channels. The sample is 8-bit 15.6KHz PCM unsigned. The engines should be
reasonably easy to understand and modify, including changing sample rates and adding stereo support.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

Both engines were written by the mighty Kev Brady / 9bitcolor.



