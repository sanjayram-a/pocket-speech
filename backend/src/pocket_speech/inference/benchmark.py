"""Run one cold and one warm benchmark against the production deployment."""

import json
import math
import statistics
import sys
import time
from typing import Protocol

import modal

APP_NAME = "pocket-speech-tts"
WARM_REQUESTS = 20
CPU_USD_PER_CORE_SECOND = 0.0000131
MEMORY_USD_PER_GIB_SECOND = 0.00000222
MEMORY_GIB = 2
SCALEDOWN_WINDOW_SECONDS = 60
CONFIGURATIONS = (
    ("torchao_2_cpu", "PocketTTSService", 2),
    ("fbgemm_2_cpu", "PocketTTSFbgemm2CpuBenchmark", 2),
    ("fbgemm_1_cpu", "PocketTTSFbgemm1CpuBenchmark", 1),
)


class _RemoteBenchmark(Protocol):
    def remote(self) -> dict[str, object]:
        """Invoke the deployed benchmark method."""


class _Service(Protocol):
    benchmark: _RemoteBenchmark


def main() -> None:
    """Print one cold and 20 warm measurements per production configuration."""
    results = {
        name: _benchmark_configuration(class_name, cpu_cores)
        for name, class_name, cpu_cores in CONFIGURATIONS
    }
    sys.stdout.write(
        json.dumps(
            results,
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )


def _benchmark_configuration(
    class_name: str,
    cpu_cores: int,
) -> dict[str, object]:
    service_class = modal.Cls.from_name(
        APP_NAME,
        class_name,
        environment_name="production",
    )
    service = service_class()
    cold = _invoke(service)
    warm = [_invoke(service) for _ in range(WARM_REQUESTS)]
    client_seconds = (
        _number(cold, "client_elapsed_ms")
        + sum(_number(result, "client_elapsed_ms") for result in warm)
    ) / 1_000
    rate = cpu_cores * CPU_USD_PER_CORE_SECOND + MEMORY_GIB * MEMORY_USD_PER_GIB_SECOND
    all_results = [cold, *warm]

    return {
        "cold": cold,
        "warm_request_count": WARM_REQUESTS,
        "warm_client_ms": _summary(warm, "client_elapsed_ms"),
        "warm_inference_ms": _summary(warm, "inference_ms"),
        "warm_realtime_factor": _summary(warm, "realtime_factor"),
        "maximum_memory_mb": max(
            _number(result, "memory_after_inference_mb") for result in all_results
        ),
        "same_container": len({str(result["container_id"]) for result in all_results})
        == 1,
        "estimated_invocation_cost_usd": round(client_seconds * rate, 6),
        "estimated_scaledown_cost_usd": round(
            SCALEDOWN_WINDOW_SECONDS * rate,
            6,
        ),
        "pricing": {
            "cpu_cores": cpu_cores,
            "memory_gib": MEMORY_GIB,
            "cpu_usd_per_core_second": CPU_USD_PER_CORE_SECOND,
            "memory_usd_per_gib_second": MEMORY_USD_PER_GIB_SECOND,
        },
    }


def _invoke(service: _Service) -> dict[str, object]:
    started_at = time.perf_counter()
    result = service.benchmark.remote()
    result["client_elapsed_ms"] = round((time.perf_counter() - started_at) * 1_000)
    return result


def _summary(results: list[dict[str, object]], field: str) -> dict[str, float]:
    values = [_number(result, field) for result in results]
    ordered = sorted(values)
    p95_index = math.ceil(0.95 * len(ordered)) - 1
    return {
        "mean": round(statistics.mean(values), 3),
        "median": round(statistics.median(values), 3),
        "p95": round(ordered[p95_index], 3),
        "minimum": round(ordered[0], 3),
        "maximum": round(ordered[-1], 3),
    }


def _number(result: dict[str, object], field: str) -> float:
    value = result[field]
    if not isinstance(value, (int, float)):
        message = f"Expected numeric benchmark field: {field}"
        raise TypeError(message)
    return float(value)


if __name__ == "__main__":
    main()
