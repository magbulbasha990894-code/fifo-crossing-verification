"""Compile and simulate the FIFO at two depths with Icarus Verilog."""
from pathlib import Path
from shutil import which
from subprocess import run
from tempfile import TemporaryDirectory


def main():
    if not which("iverilog") or not which("vvp"):
        raise SystemExit("Icarus Verilog is required (iverilog and vvp on PATH).")
    root = Path(__file__).resolve().parent
    with TemporaryDirectory() as tmp:
        for bits in (2, 4):
            image = str(Path(tmp) / f"fifo_{bits}.vvp")
            run(["iverilog", "-Wall", "-g2012", "-s", "async_fifo_tb",
                 f"-Pasync_fifo_tb.ADDR_BITS={bits}", "-o", image,
                 "rtl/async_fifo.v", "tb/async_fifo_tb.sv"], cwd=root, check=True)
            run(["vvp", image], cwd=root, check=True)


if __name__ == "__main__":
    main()
