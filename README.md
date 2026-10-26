# Spacewire
Development of a SpaceWire router in SystemVerilog, with a verification environment to validate its functionality. The project covers routing, arbitration, crossbar switching, and flow control, as well as Low Power Design techniques such as clock gating and voltage islands to reduce energy consumption.

## Clone

This repository uses Git submodules (the PDK libraries are kept in a separate `saed90` repository). To clone everything at once, including the submodules:

```bash
git clone --recurse-submodules https://github.com/viniciuskant/spacewire.git
```

If you already cloned the repository without `--recurse-submodules`, the submodule folders will be empty. Run `git submodule update --init --recursive` from the repository root to fetch their contents.

## Synthesis

The design can be synthesized for different PDKs. To select a technology, define the `PDK_MACRO` environment variable in your `setup.sh` script (or export it directly in your terminal):

```bash
export PDK_MACRO=SAED32   # Options: SAED32, SAED90, or IHP130
```