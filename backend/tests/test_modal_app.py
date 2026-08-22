import pytest

from pocket_speech.inference.modal_app import (
    MAX_REFERENCE_BYTES,
    MAX_TEXT_CHARACTERS,
    _validate_bytes,
    _validate_text,
)


def test_accepts_bounded_inference_inputs() -> None:
    _validate_text("Generate this sentence.")
    _validate_bytes(b"wav", name="reference WAV", maximum=MAX_REFERENCE_BYTES)


@pytest.mark.parametrize("text", ["", "   ", "\n\t"])
def test_rejects_blank_generation_text(text: str) -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        _validate_text(text)


def test_rejects_generation_text_over_the_policy_ceiling() -> None:
    with pytest.raises(ValueError, match="maximum character count"):
        _validate_text("a" * (MAX_TEXT_CHARACTERS + 1))


def test_rejects_empty_or_oversized_binary_inputs() -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        _validate_bytes(b"", name="voice state", maximum=4)
    with pytest.raises(ValueError, match="maximum size"):
        _validate_bytes(b"12345", name="voice state", maximum=4)
