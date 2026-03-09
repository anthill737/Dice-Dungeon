#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import os
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_FILE = REPO_ROOT / ".env"
DEFAULT_MANIFEST = REPO_ROOT / "godot_port" / "assets" / "audio" / "sfx_manifest.json"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "godot_port" / "assets" / "audio" / "sfx"
DEFAULT_LOG_FILE = REPO_ROOT / "logs" / "sfx_generation.log"

DEFAULT_BASE_URL = "https://api.elevenlabs.io"
DEFAULT_MODEL_ID = "eleven_text_to_sound_v2"
DEFAULT_OUTPUT_FORMAT = "pcm_44100"
FALLBACK_OUTPUT_FORMAT = "mp3_44100_128"


class ApiRequestError(RuntimeError):
    def __init__(self, status_code: int, message: str, headers: dict[str, str] | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.message = message
        self.headers = headers or {}


@dataclass(frozen=True)
class SoundEffectSpec:
    sound_id: str
    prompt: str
    file_stem: str
    duration_seconds: float | None
    prompt_influence: float | None
    loop: bool


@dataclass(frozen=True)
class AppConfig:
    env_file: Path
    manifest_path: Path
    output_dir: Path
    log_file: Path
    base_url: str
    api_key: str | None
    model_id: str
    output_format: str
    only_ids: frozenset[str] | None
    exclude_ids: frozenset[str]
    overwrite: bool
    dry_run: bool
    timeout_seconds: float
    max_retries: int
    base_backoff_seconds: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Dice Dungeon sound effects from a manifest using ElevenLabs."
    )
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Path to a .env file.")
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Path to the JSON sound-effect manifest.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory where generated sound effects will be written.",
    )
    parser.add_argument(
        "--log-file",
        default=str(DEFAULT_LOG_FILE),
        help="File used for run logs.",
    )
    parser.add_argument(
        "--base-url",
        default=None,
        help="Override ElevenLabs base URL.",
    )
    parser.add_argument(
        "--model-id",
        default=None,
        help="Override the ElevenLabs sound generation model ID.",
    )
    parser.add_argument(
        "--output-format",
        default=None,
        help="Preferred ElevenLabs output format. Defaults to pcm_44100 with mp3 fallback.",
    )
    parser.add_argument(
        "--only-ids",
        action="append",
        default=[],
        help="Comma-separated list of sound ids to process.",
    )
    parser.add_argument(
        "--exclude-ids",
        action="append",
        default=[],
        help="Comma-separated list of sound ids to skip.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Regenerate sounds even if a target file already exists.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be generated without calling the API.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=120.0,
        help="Per-request timeout in seconds.",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=4,
        help="Maximum retries for rate limits and transient failures.",
    )
    parser.add_argument(
        "--base-backoff",
        type=float,
        default=2.0,
        help="Base backoff in seconds for retries.",
    )
    return parser.parse_args()


def load_env_file(path: Path) -> None:
    if not path.is_file():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        os.environ.setdefault(key, value)


def build_config(args: argparse.Namespace) -> AppConfig:
    env_file = Path(args.env_file).resolve()
    load_env_file(env_file)
    only_ids = parse_id_filters(args.only_ids)
    exclude_ids = parse_id_filters(args.exclude_ids) or frozenset()

    return AppConfig(
        env_file=env_file,
        manifest_path=Path(args.manifest).resolve(),
        output_dir=Path(args.output_dir).resolve(),
        log_file=Path(args.log_file).resolve(),
        base_url=(args.base_url or os.getenv("ELEVENLABS_BASE_URL") or DEFAULT_BASE_URL).rstrip("/"),
        api_key=os.getenv("ELEVENLABS_API_KEY"),
        model_id=args.model_id or os.getenv("ELEVENLABS_MODEL_ID") or DEFAULT_MODEL_ID,
        output_format=args.output_format or os.getenv("ELEVENLABS_OUTPUT_FORMAT") or DEFAULT_OUTPUT_FORMAT,
        only_ids=only_ids,
        exclude_ids=exclude_ids,
        overwrite=args.overwrite,
        dry_run=args.dry_run,
        timeout_seconds=max(args.timeout, 1.0),
        max_retries=max(args.max_retries, 0),
        base_backoff_seconds=max(args.base_backoff, 0.1),
    )


def parse_id_filters(raw_values: list[str]) -> frozenset[str] | None:
    ids: set[str] = set()
    for raw_value in raw_values:
        if not isinstance(raw_value, str):
            continue
        for token in raw_value.split(","):
            sound_id = token.strip()
            if sound_id:
                ids.add(sound_id)
    if not ids:
        return None
    return frozenset(ids)


def setup_logging(log_file: Path) -> None:
    log_file.parent.mkdir(parents=True, exist_ok=True)
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(logging.INFO)

    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setFormatter(formatter)
    root_logger.addHandler(stream_handler)

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)


def load_manifest(path: Path) -> list[SoundEffectSpec]:
    if not path.is_file():
        raise FileNotFoundError(f"Manifest file not found: {path}")

    data = json.loads(path.read_text(encoding="utf-8"))
    defaults = data.get("defaults", {})
    raw_sounds = data.get("sounds")

    if not isinstance(defaults, dict):
        raise ValueError("Manifest defaults must be an object.")
    if not isinstance(raw_sounds, list) or not raw_sounds:
        raise ValueError("Manifest must define a non-empty sounds array.")

    specs: list[SoundEffectSpec] = []
    seen_ids: set[str] = set()

    for index, raw_sound in enumerate(raw_sounds, start=1):
        if not isinstance(raw_sound, dict):
            raise ValueError(f"Sound entry #{index} must be an object.")
        merged = dict(defaults)
        merged.update(raw_sound)

        sound_id = expect_string(merged, "id", index)
        prompt = expect_string(merged, "prompt", index)
        file_stem = str(merged.get("file_stem") or f"sfx_{sound_id}").strip()
        duration_seconds = optional_float(merged.get("duration_seconds"), "duration_seconds", index)
        prompt_influence = optional_float(merged.get("prompt_influence"), "prompt_influence", index)
        loop = bool(merged.get("loop", False))

        if not re.fullmatch(r"[a-z0-9_]+", sound_id):
            raise ValueError(f"Sound entry #{index} has invalid id {sound_id!r}.")
        if sound_id in seen_ids:
            raise ValueError(f"Duplicate sound id found: {sound_id}")
        if not re.fullmatch(r"[A-Za-z0-9_\\-]+", file_stem):
            raise ValueError(f"Sound entry #{index} has invalid file_stem {file_stem!r}.")
        if duration_seconds is not None and not 0.5 <= duration_seconds <= 30:
            raise ValueError(f"Sound entry #{index} duration_seconds must be between 0.5 and 30.")
        if prompt_influence is not None and not 0.0 <= prompt_influence <= 1.0:
            raise ValueError(f"Sound entry #{index} prompt_influence must be between 0 and 1.")

        seen_ids.add(sound_id)
        specs.append(
            SoundEffectSpec(
                sound_id=sound_id,
                prompt=prompt,
                file_stem=file_stem,
                duration_seconds=duration_seconds,
                prompt_influence=prompt_influence,
                loop=loop,
            )
        )

    return specs


def filter_sounds(
    sounds: list[SoundEffectSpec],
    only_ids: frozenset[str] | None,
    exclude_ids: frozenset[str],
) -> list[SoundEffectSpec]:
    filtered = sounds
    if only_ids:
        filtered = [sound for sound in filtered if sound.sound_id in only_ids]
    if exclude_ids:
        filtered = [sound for sound in filtered if sound.sound_id not in exclude_ids]
    return filtered


def expect_string(data: dict[str, Any], key: str, index: int) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Sound entry #{index} is missing a valid {key!r}.")
    return value.strip()


def optional_float(value: Any, key: str, index: int) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    raise ValueError(f"Sound entry #{index} has invalid {key!r}; expected a number or null.")


def build_output_format_chain(preferred_format: str) -> list[str]:
    preferred = preferred_format.strip()
    if not preferred:
        preferred = DEFAULT_OUTPUT_FORMAT

    formats = [preferred]
    if preferred.startswith("pcm_") and preferred != FALLBACK_OUTPUT_FORMAT:
        formats.append(FALLBACK_OUTPUT_FORMAT)
    return formats


def extension_for_output_format(output_format: str) -> str:
    if output_format.startswith("pcm_"):
        return ".wav"
    if output_format.startswith("mp3_"):
        return ".mp3"
    codec = output_format.split("_", 1)[0].strip() or "audio"
    return f".{codec}"


def candidate_paths(output_dir: Path, file_stem: str, output_format_chain: list[str]) -> list[Path]:
    unique_paths: list[Path] = []
    seen: set[Path] = set()
    for output_format in output_format_chain:
        path = output_dir / f"{file_stem}{extension_for_output_format(output_format)}"
        if path not in seen:
            seen.add(path)
            unique_paths.append(path)
    return unique_paths


def parse_retry_after(headers: dict[str, str]) -> float | None:
    retry_after = headers.get("Retry-After")
    if not retry_after:
        return None
    try:
        return max(float(retry_after), 0.0)
    except ValueError:
        try:
            retry_at = parsedate_to_datetime(retry_after)
        except (TypeError, ValueError):
            return None
        if retry_at.tzinfo is None:
            retry_at = retry_at.replace(tzinfo=timezone.utc)
        return max((retry_at - datetime.now(timezone.utc)).total_seconds(), 0.0)


def compute_backoff(attempt_index: int, base_backoff_seconds: float, headers: dict[str, str]) -> float:
    retry_after = parse_retry_after(headers)
    if retry_after is not None:
        return retry_after
    exponential = base_backoff_seconds * (2 ** attempt_index)
    jitter = random.uniform(0.0, 0.5)
    return exponential + jitter


def parse_error_message(body: bytes, fallback: str) -> str:
    if not body:
        return fallback

    try:
        payload = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        text = body.decode("utf-8", errors="replace").strip()
        return text or fallback

    if isinstance(payload, dict):
        detail = payload.get("detail")
        if isinstance(detail, str) and detail.strip():
            return detail.strip()
        if isinstance(detail, dict):
            for key in ("message", "detail", "status"):
                value = detail.get(key)
                if isinstance(value, str) and value.strip():
                    return value.strip()
        if isinstance(detail, list):
            for entry in detail:
                if isinstance(entry, dict):
                    value = entry.get("msg") or entry.get("message") or entry.get("detail")
                    if isinstance(value, str) and value.strip():
                        return value.strip()
                if isinstance(entry, str) and entry.strip():
                    return entry.strip()
        for key in ("message", "error"):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()

    return fallback


def request_sound_effect(
    config: AppConfig,
    sound: SoundEffectSpec,
    output_format: str,
) -> tuple[bytes, dict[str, str]]:
    endpoint = f"{config.base_url}/v1/sound-generation"
    query = urllib.parse.urlencode({"output_format": output_format})
    url = f"{endpoint}?{query}"

    body: dict[str, Any] = {
        "text": sound.prompt,
        "model_id": config.model_id,
        "loop": sound.loop,
    }
    if sound.duration_seconds is not None:
        body["duration_seconds"] = sound.duration_seconds
    if sound.prompt_influence is not None:
        body["prompt_influence"] = sound.prompt_influence

    data = json.dumps(body).encode("utf-8")

    for attempt in range(config.max_retries + 1):
        request = urllib.request.Request(
            url=url,
            data=data,
            method="POST",
            headers={
                "Accept": "audio/mpeg, audio/wav, application/octet-stream",
                "Content-Type": "application/json",
                "xi-api-key": config.api_key or "",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=config.timeout_seconds) as response:
                return response.read(), dict(response.headers.items())
        except urllib.error.HTTPError as exc:
            response_body = exc.read()
            headers = dict(exc.headers.items())
            message = parse_error_message(response_body, f"HTTP {exc.code}")
            if exc.code == 429 and attempt < config.max_retries:
                sleep_seconds = compute_backoff(attempt, config.base_backoff_seconds, headers)
                logging.warning(
                    "[RETRY] %s rate limited for output_format=%s; retrying in %.1fs",
                    sound.sound_id,
                    output_format,
                    sleep_seconds,
                )
                time.sleep(sleep_seconds)
                continue
            if 500 <= exc.code < 600 and attempt < config.max_retries:
                sleep_seconds = compute_backoff(attempt, config.base_backoff_seconds, headers)
                logging.warning(
                    "[RETRY] %s server error for output_format=%s; retrying in %.1fs (%s)",
                    sound.sound_id,
                    output_format,
                    sleep_seconds,
                    message,
                )
                time.sleep(sleep_seconds)
                continue
            raise ApiRequestError(exc.code, message, headers) from exc
        except urllib.error.URLError as exc:
            if attempt < config.max_retries:
                sleep_seconds = compute_backoff(attempt, config.base_backoff_seconds, {})
                logging.warning(
                    "[RETRY] %s network error for output_format=%s; retrying in %.1fs (%s)",
                    sound.sound_id,
                    output_format,
                    sleep_seconds,
                    exc.reason,
                )
                time.sleep(sleep_seconds)
                continue
            raise ApiRequestError(0, str(exc.reason), {}) from exc

    raise ApiRequestError(0, "Unknown request failure", {})


def write_audio_file(path: Path, output_format: str, audio_bytes: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if output_format.startswith("pcm_"):
        write_pcm_as_wav(path, output_format, audio_bytes)
        return
    write_bytes(path, audio_bytes)


def write_bytes(path: Path, payload: bytes) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_bytes(payload)
    tmp_path.replace(path)


def write_pcm_as_wav(path: Path, output_format: str, audio_bytes: bytes) -> None:
    if audio_bytes.startswith(b"RIFF"):
        write_bytes(path, audio_bytes)
        return

    match = re.match(r"pcm_(\d+)", output_format)
    if not match:
        raise ValueError(f"Unsupported PCM output format: {output_format}")
    sample_rate = int(match.group(1))

    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with wave.open(str(tmp_path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_bytes)
    tmp_path.replace(path)


def cleanup_alternate_outputs(current_path: Path, all_candidate_paths: list[Path]) -> None:
    for candidate in all_candidate_paths:
        if candidate != current_path and candidate.exists():
            candidate.unlink()


def ensure_api_key(config: AppConfig) -> None:
    if config.dry_run:
        return
    if config.api_key:
        return
    raise SystemExit(
        "Missing ELEVENLABS_API_KEY. Add it to a local .env file or export it in your shell."
    )


def process_sound(
    config: AppConfig,
    sound: SoundEffectSpec,
    output_format_chain: list[str],
) -> str:
    paths = candidate_paths(config.output_dir, sound.file_stem, output_format_chain)
    existing_path = next((path for path in paths if path.exists()), None)

    if existing_path and not config.overwrite:
        logging.info("[SKIP] %s -> %s already exists", sound.sound_id, existing_path)
        return "skipped"

    if config.dry_run:
        target_list = ", ".join(str(path) for path in paths)
        logging.info("[DRY RUN] %s -> would generate %s", sound.sound_id, target_list)
        return "dry-run"

    last_error: ApiRequestError | None = None

    for output_format in output_format_chain:
        try:
            audio_bytes, headers = request_sound_effect(config, sound, output_format)
            output_path = config.output_dir / f"{sound.file_stem}{extension_for_output_format(output_format)}"
            write_audio_file(output_path, output_format, audio_bytes)
            cleanup_alternate_outputs(output_path, paths)
            character_cost = headers.get("character-cost")
            if character_cost:
                logging.info(
                    "[OK] %s -> %s (%s, character-cost=%s)",
                    sound.sound_id,
                    output_path,
                    output_format,
                    character_cost,
                )
            else:
                logging.info("[OK] %s -> %s (%s)", sound.sound_id, output_path, output_format)
            return "generated"
        except ApiRequestError as exc:
            last_error = exc
            is_pcm_fallback = output_format.startswith("pcm_") and output_format != FALLBACK_OUTPUT_FORMAT
            has_more_formats = output_format != output_format_chain[-1]
            if is_pcm_fallback and has_more_formats and exc.status_code == 422:
                logging.warning(
                    "[FALLBACK] %s could not use %s (%s). Trying %s instead.",
                    sound.sound_id,
                    output_format,
                    exc.message,
                    FALLBACK_OUTPUT_FORMAT,
                )
                continue
            break

    assert last_error is not None
    logging.error(
        "[FAIL] %s -> status=%s message=%s",
        sound.sound_id,
        last_error.status_code,
        last_error.message,
    )
    return "failed"


def main() -> int:
    args = parse_args()
    config = build_config(args)
    setup_logging(config.log_file)
    ensure_api_key(config)

    sounds = load_manifest(config.manifest_path)
    sounds = filter_sounds(sounds, config.only_ids, config.exclude_ids)
    output_format_chain = build_output_format_chain(config.output_format)

    if not sounds:
        logging.error("No sounds matched the provided manifest and id filters.")
        return 1

    logging.info("Using manifest: %s", config.manifest_path)
    logging.info("Output directory: %s", config.output_dir)
    logging.info("Requested output format chain: %s", ", ".join(output_format_chain))
    if config.only_ids:
        logging.info("Only ids: %s", ", ".join(sorted(config.only_ids)))
    if config.exclude_ids:
        logging.info("Excluded ids: %s", ", ".join(sorted(config.exclude_ids)))
    if config.overwrite:
        logging.info("Overwrite mode enabled")
    if config.dry_run:
        logging.info("Dry-run mode enabled; no API requests will be sent")

    results = {"generated": 0, "skipped": 0, "dry-run": 0, "failed": 0}

    for sound in sounds:
        result = process_sound(config, sound, output_format_chain)
        results[result] += 1

    logging.info(
        "Summary: generated=%d skipped=%d dry_run=%d failed=%d",
        results["generated"],
        results["skipped"],
        results["dry-run"],
        results["failed"],
    )

    return 1 if results["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
