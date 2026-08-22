"""Private Pocket TTS inference service deployed on Modal."""

from __future__ import annotations

import hashlib
import socket
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

import modal

APP_NAME = "pocket-speech-tts"
MODEL_LANGUAGE = "english_2026-04"
MODEL_VERSION = "pocket-tts-2.1.0-english-2026-04-int8"
MAX_REFERENCE_BYTES = 10 * 1024 * 1024
MAX_VOICE_STATE_BYTES = 64 * 1024 * 1024
MAX_TEXT_CHARACTERS = 1_000
BENCHMARK_TEXT = "Pocket Speech production inference benchmark."
EMPTY_TEXT_ERROR = "text must not be empty"
TEXT_TOO_LONG_ERROR = "text exceeds the maximum character count"

hf_secret = modal.Secret.from_name(
    "huggingface-secret",
    environment_name="production",
    required_keys=["HF_TOKEN"],
)


def download_model() -> None:
    """Bake the fixed model and benchmark voice into the image cache."""
    from pocket_tts import TTSModel  # noqa: PLC0415

    model = TTSModel.load_model(language=MODEL_LANGUAGE, quantize=False)
    model.get_state_for_audio_prompt("alba")


base_image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "libsndfile1")
    .uv_pip_install(
        "torch==2.13.0+cpu",
        "pocket-tts[audio]==2.1.0",
        extra_index_url="https://download.pytorch.org/whl/cpu",
    )
    .run_function(download_model, secrets=[hf_secret])
)
torchao_image = base_image.uv_pip_install(
    "torchao==0.18.0+cpu",
    extra_index_url="https://download.pytorch.org/whl/cpu",
)

app = modal.App(APP_NAME)


class _BenchmarkImplementation:
    """Shared model lifecycle and benchmark implementation."""

    def _load_benchmark_model(self, expected_backend: str) -> None:
        import torch  # noqa: PLC0415
        from pocket_tts import TTSModel  # noqa: PLC0415
        from pocket_tts.quantization import _get_backend  # noqa: PLC0415

        if expected_backend == "torch.ao":
            torch.backends.quantized.engine = "fbgemm"

        quantization_backend = _get_backend()
        if quantization_backend != expected_backend:
            message = (
                f"Expected {expected_backend} quantization, got {quantization_backend}"
            )
            raise RuntimeError(message)

        started_at = time.perf_counter()
        memory_before_mb = _memory_mb()
        self.model = TTSModel.load_model(
            language=MODEL_LANGUAGE,
            quantize=True,
        )
        model_loaded_at = time.perf_counter()
        self.benchmark_voice = self.model.get_state_for_audio_prompt("alba")
        self.startup_metrics = {
            "model_load_ms": _milliseconds(model_loaded_at - started_at),
            "benchmark_voice_load_ms": _milliseconds(
                time.perf_counter() - model_loaded_at
            ),
            "memory_before_model_mb": memory_before_mb,
            "memory_after_model_mb": _memory_mb(),
        }
        self.container_id = f"{socket.gethostname()}-{uuid.uuid4().hex[:8]}"
        self.request_count = 0
        self.quantization_backend = quantization_backend
        self.quantization_engine = torch.backends.quantized.engine

    def _run_benchmark(self) -> dict[str, object]:
        self.request_count += 1
        memory_before_mb = _memory_mb()
        started_at = time.perf_counter()
        audio = self.model.generate_audio(
            self.benchmark_voice,
            BENCHMARK_TEXT,
        )
        inference_seconds = time.perf_counter() - started_at
        audio_seconds = audio.numel() / self.model.sample_rate

        return {
            "container_id": self.container_id,
            "container_request": self.request_count,
            "model_version": MODEL_VERSION,
            "quantized": True,
            "quantization_backend": self.quantization_backend,
            "quantization_engine": self.quantization_engine,
            "sample_rate": self.model.sample_rate,
            "audio_ms": _milliseconds(audio_seconds),
            "inference_ms": _milliseconds(inference_seconds),
            "realtime_factor": round(inference_seconds / audio_seconds, 3),
            "memory_before_inference_mb": memory_before_mb,
            "memory_after_inference_mb": _memory_mb(),
            **self.startup_metrics,
        }


@app.cls(
    image=torchao_image,
    cpu=2.0,
    memory=2048,
    min_containers=0,
    max_containers=1,
    scaledown_window=60,
    timeout=300,
    startup_timeout=300,
    secrets=[hf_secret],
)
class PocketTTSService(_BenchmarkImplementation):
    """One non-concurrent Pocket TTS model per Modal container."""

    @modal.enter()
    def load(self) -> None:
        """Load one quantized model and the synthetic benchmark voice."""
        self._load_benchmark_model("torchao")

    @modal.method()
    def clone_voice(self, reference_wav: bytes) -> dict[str, object]:
        """Create a voice state without retaining the reference recording."""
        _validate_bytes(
            reference_wav,
            name="reference WAV",
            maximum=MAX_REFERENCE_BYTES,
        )

        from pocket_tts import export_model_state  # noqa: PLC0415

        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            reference_path = directory / "reference.wav"
            state_path = directory / "voice.safetensors"
            reference_path.write_bytes(reference_wav)
            state = self.model.get_state_for_audio_prompt(
                reference_path,
                truncate=True,
            )
            export_model_state(state, state_path)
            state_bytes = state_path.read_bytes()

        return {
            "voice_state": state_bytes,
            "voice_state_sha256": hashlib.sha256(state_bytes).hexdigest(),
            "model_version": MODEL_VERSION,
        }

    @modal.method()
    def generate_speech(self, voice_state: bytes, text: str) -> dict[str, object]:
        """Generate MP3 bytes from a validated voice state and bounded text."""
        _validate_bytes(
            voice_state,
            name="voice state",
            maximum=MAX_VOICE_STATE_BYTES,
        )
        _validate_text(text)

        started_at = time.perf_counter()
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            state_path = directory / "voice.safetensors"
            state_path.write_bytes(voice_state)
            state = self.model.get_state_for_audio_prompt(state_path)
            audio = self.model.generate_audio(state, text)
            generated_ms = round(audio.numel() * 1_000 / self.model.sample_rate)
            mp3_bytes = _encode_mp3(
                audio.detach().cpu().numpy(),
                self.model.sample_rate,
                directory,
            )

        return {
            "audio_mp3": mp3_bytes,
            "generated_ms": generated_ms,
            "inference_ms": _milliseconds(time.perf_counter() - started_at),
            "model_version": MODEL_VERSION,
            "voice_state_sha256": hashlib.sha256(voice_state).hexdigest(),
        }

    @modal.method()
    def benchmark(self) -> dict[str, object]:
        """Measure one synthetic generation without returning or retaining audio."""
        return self._run_benchmark()


@app.cls(
    image=base_image,
    cpu=2.0,
    memory=2048,
    min_containers=0,
    max_containers=1,
    scaledown_window=60,
    timeout=300,
    startup_timeout=300,
    secrets=[hf_secret],
)
class PocketTTSFbgemm2CpuBenchmark(_BenchmarkImplementation):
    """Two-core torch.ao/FBGEMM benchmark variant."""

    @modal.enter()
    def load(self) -> None:
        """Load the FBGEMM-quantized model once per container."""
        self._load_benchmark_model("torch.ao")

    @modal.method()
    def benchmark(self) -> dict[str, object]:
        """Run one fixed-input benchmark generation."""
        return self._run_benchmark()


@app.cls(
    image=base_image,
    cpu=1.0,
    memory=2048,
    min_containers=0,
    max_containers=1,
    scaledown_window=60,
    timeout=300,
    startup_timeout=300,
    secrets=[hf_secret],
)
class PocketTTSFbgemm1CpuBenchmark(_BenchmarkImplementation):
    """One-core torch.ao/FBGEMM benchmark variant."""

    @modal.enter()
    def load(self) -> None:
        """Load the FBGEMM-quantized model once per container."""
        self._load_benchmark_model("torch.ao")

    @modal.method()
    def benchmark(self) -> dict[str, object]:
        """Run one fixed-input benchmark generation."""
        return self._run_benchmark()


def _validate_bytes(value: bytes, *, name: str, maximum: int) -> None:
    if not value:
        message = f"{name} must not be empty"
        raise ValueError(message)
    if len(value) > maximum:
        message = f"{name} exceeds the maximum size"
        raise ValueError(message)


def _validate_text(text: str) -> None:
    if not text.strip():
        raise ValueError(EMPTY_TEXT_ERROR)
    if len(text) > MAX_TEXT_CHARACTERS:
        raise ValueError(TEXT_TOO_LONG_ERROR)


def _encode_mp3(audio: object, sample_rate: int, directory: Path) -> bytes:
    import scipy.io.wavfile  # noqa: PLC0415

    wav_path = directory / "speech.wav"
    mp3_path = directory / "speech.mp3"
    scipy.io.wavfile.write(wav_path, sample_rate, audio)
    subprocess.run(  # noqa: S603
        [
            "/usr/bin/ffmpeg",
            "-nostdin",
            "-loglevel",
            "error",
            "-i",
            str(wav_path),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "128k",
            str(mp3_path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    return mp3_path.read_bytes()


def _memory_mb() -> float:
    for memory_path in (
        Path("/sys/fs/cgroup/memory.current"),
        Path("/sys/fs/cgroup/memory/memory.usage_in_bytes"),
    ):
        if memory_path.exists():
            return round(int(memory_path.read_text().strip()) / (1024 * 1024), 1)

    try:
        import resource  # noqa: PLC0415
    except ImportError:
        return -1.0
    return round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1)


def _milliseconds(seconds: float) -> int:
    return round(seconds * 1_000)
