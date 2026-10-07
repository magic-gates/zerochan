from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import cocotb
import numpy as np

BSIZE = 480
N_SYM = 100

@cocotb.test()
async def test(dut):
    Clock(dut.clk, 10, unit="ns").start()
    await reset(dut)

    # signal = [ 2047 + 0j ] * (N_SYM * BSIZE)
    signal = generate_qpsk(N_SYM * BSIZE) * 2047

    cocotb.start_soon(channel(dut))

    await tx(dut, signal)

async def channel(dut):
    dut.tx_m_ready.value = 1

    cfo_effect = CFOChannel(cfo=-3.2)
    path_effect = MultipathChannel(taps=[1.0, 0.3 + 0.2j, 0.1j])
    awgn_effect = AWGNChannel(snr_db=20, sig_pwr=2047.0**2)

    while True:
        dut.rx_ce.value = dut.tx_m_valid.value

        re = dut.tx_m_re.value.to_signed()
        im = dut.tx_m_im.value.to_signed()
        sample = complex(re, im)

        # sample = cfo_effect.apply(sample)
        # sample = path_effect.apply(sample)
        # sample = awgn_effect.apply(sample)

        dut.rx_s_re.value = int(
            np.clip(sample.real, -2048, 2047).astype(np.int16)
        )
        dut.rx_s_im.value = int(
            np.clip(sample.imag, -2048, 2047).astype(np.int16)
        )

        await RisingEdge(dut.clk)

async def tx(dut, signal):
    for sample in signal:
        dut.tx_s_re.value = int(np.clip(sample.real, -2048, 2047).astype(np.int16))
        dut.tx_s_im.value = int(np.clip(sample.imag, -2048, 2047).astype(np.int16))
        dut.tx_s_valid.value = 1;

        while True:
            await RisingEdge(dut.clk)
            if dut.tx_s_ready.value == 1:
                break

def generate_qpsk(n):
    symbols = np.array([1+1j, -1+1j, -1-1j, 1-1j])
    # symbols = np.array([1+0j, 0+1j, -1+0j, 0-1j])
    return np.random.choice(symbols, size=n)

def generate_64qam(size):
    """Generates normalized 64-QAM symbols."""
    # 64-QAM values: +/-1, +/-3, +/-5, +/-7
    qam_vals = np.array([-7, -5, -3, -1, 1, 3, 5, 7])
    re = np.random.choice(qam_vals, size)
    im = np.random.choice(qam_vals, size)
    syms = re + 1j * im
    return syms / 7.0

class CFOChannel:

    def __init__(self, cfo, fft_len=1024):
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


async def reset(dut):
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
