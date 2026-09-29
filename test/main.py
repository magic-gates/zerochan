from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import cocotb
import numpy as np
import matplotlib.pyplot as plt

FFT_LEN = 1024
N_SYM = 300_000
SKIP_SYM = 200_000

@cocotb.test()
async def test(dut):
    Clock(dut.clk, 10, unit="ns").start()
    await reset(dut)

    cocotb.start_soon(tx(dut, N_SYM));
    cocotb.start_soon(channel(dut))

    captured = await rx(dut)

    plot(captured)

async def rx(dut):
    rx_sym = 0

    captured = []

    while rx_sym < N_SYM - 20_000:
        await RisingEdge(dut.clk)

        if dut.o_rx_valid.value == 1:
            idx = dut.o_rx_idx.value.to_unsigned()
            rx_sym += 1

            if rx_sym > SKIP_SYM:
                re = dut.o_rx_re.value.to_signed()
                im = dut.o_rx_im.value.to_signed()
                captured.append(complex(re, im))

    return np.array(captured)

def test_signal(n_sym):
    # return np.full(n_sym, 0 + 0j)
    return generate_qpsk(n_sym) * 511.0

async def external_channel(dut):
    data = np.fromfile("signal.bin", dtype=np.int16)

    I = data[0::2]
    Q = data[1::2]

    signal = I + 1j * Q

    for sample in signal:
        dut.i_loop_re.value = int(
            np.clip(sample.real, -2048, 2047).astype(np.int16)
        )
        dut.i_loop_im.value = int(
            np.clip(sample.imag, -2048, 2047).astype(np.int16)
        )

        await RisingEdge(dut.clk)

async def channel(dut):
    """Sample-by-sample channel processing loop."""
    cfo_effect = CFOChannel(cfo=0.4)
    path_effect = MultipathChannel(taps=[1.0, 0.3 + 0.2j, 0.1j])
    awgn_effect = AWGNChannel(snr_db=55, sig_pwr=2047.0**2)

    while True:
        # Read sample from loopback output pins
        re_in = dut.o_loop_re.value.to_signed()
        im_in = dut.o_loop_im.value.to_signed()
        sample = complex(re_in, im_in)

        # Apply channel pipeline sample by sample
        sample = cfo_effect.apply(sample)
        sample = path_effect.apply(sample)
        sample = awgn_effect.apply(sample)

        dut.i_loop_re.value = int(
            np.clip(sample.real, -2048, 2047).astype(np.int16)
        )
        dut.i_loop_im.value = int(
            np.clip(sample.imag, -2048, 2047).astype(np.int16)
        )

        # dut.i_loop_re.value = dut.o_loop_re.value;
        # dut.i_loop_im.value = dut.o_loop_im.value;

        await RisingEdge(dut.clk)

async def tx(dut, n_sym):
    tx_signal = test_signal(n_sym)
    await feed(dut, tx_signal)

async def feed(dut, signal):
    for sample in signal:
        dut.i_tx_re.value = int(np.clip(sample.real, -512, 511).astype(np.int16))
        dut.i_tx_im.value = int(np.clip(sample.imag, -512, 511).astype(np.int16))
        dut.i_tx_valid.value = 1;
        await RisingEdge(dut.clk)

        if (dut.o_tx_ready.value != 1):
            await RisingEdge(dut.o_tx_ready)

# def apply_awgn(signal, snr_db):
#     sig_pwr = np.mean(np.abs(signal)**2)
#     noise_pwr = sig_pwr / (10**(snr_db / 10))
#     noise = np.sqrt(noise_pwr / 2) * (np.random.randn(len(signal)) + 1j * np.random.randn(len(signal)))
#     return signal + noise

# def apply_cfo(signal, cfo):
#     t = np.arange(len(signal))
#     return signal * np.exp(1j * 2 * np.pi * cfo * t / FFT_LEN)

# def apply_paths(signal, taps):
#     return np.convolve(signal, taps, mode='same')

def plot(s):
    plt.figure(figsize=(10, 10))
    plt.scatter(s.real, s.imag, s=0.2)
    # plt.hist2d(s.real, s.imag, bins=256, cmap='viridis')
    # plt.colorbar(label='Density')
    plt.title(f"Constellation")
    plt.xlabel("Re")
    plt.ylabel("Im")
    plt.grid(True, alpha=0.3)
    plt.show()
    plt.savefig("constallation.png")

def generate_64qam(size):
    """Generates normalized 64-QAM symbols."""
    # 64-QAM values: +/-1, +/-3, +/-5, +/-7
    qam_vals = np.array([-7, -5, -3, -1, 1, 3, 5, 7])
    re = np.random.choice(qam_vals, size)
    im = np.random.choice(qam_vals, size)
    syms = re + 1j * im
    return syms / 7.0

def generate_qpsk(n):
    symbols = np.array([1+1j, -1+1j, -1-1j, 1-1j])
    return np.random.choice(symbols, size=n)

async def reset(dut):
    dut.arst.value = 1
    await RisingEdge(dut.clk)
    dut.arst.value = 0

class CFOChannel:

    def __init__(self, cfo, fft_len=FFT_LEN):
        self.cfo = cfo
        self.fft_len = fft_len
        self.n = 0

    def apply(self, sample: complex) -> complex:
        phase = 2 * np.pi * self.cfo * self.n / self.fft_len
        out = sample * np.exp(1j * phase)
        self.n += 1
        return out


class MultipathChannel:

    def __init__(self, taps):
        self.taps = np.array(taps, dtype=complex)
        # Buffer to store past samples for FIR filtering
        self.buffer = np.zeros(len(taps), dtype=complex)

    def apply(self, sample: complex) -> complex:
        # Shift buffer and insert new sample at index 0
        self.buffer = np.roll(self.buffer, 1)
        self.buffer[0] = sample
        # Compute dot product (FIR convolution step)
        return np.dot(self.buffer, self.taps)


class AWGNChannel:

    def __init__(self, snr_db, sig_pwr=1.0):
        self.snr_db = snr_db
        # Pre-calculate noise standard deviation per real/imag dimension
        noise_pwr = sig_pwr / (10 ** (snr_db / 10))
        self.std_dev = np.sqrt(noise_pwr / 2)

    def apply(self, sample: complex) -> complex:
        noise = self.std_dev * (
            np.random.randn() + 1j * np.random.randn()
        )
        return sample + noise
