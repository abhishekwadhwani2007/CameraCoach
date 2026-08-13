import logging
import sys
import traceback
from pathlib import Path
from tempfile import NamedTemporaryFile

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from outline import generate_transparent_overlay


# Reconfigure before any logging so UTF-8 emoji / non-ASCII chars don't crash
# Windows terminals or cloud log collectors.
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
    stream=sys.stdout,
)
logger = logging.getLogger("posecoach")

limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="PoseCoach Overlay API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS is open because the app can run on any device IP. Tighten to specific
# origins if you ever expose this publicly beyond Hugging Face Spaces.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# We read uploads in 1 MB chunks and bail early, so an oversized file never
# gets fully buffered into memory before we reject it.
_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}
_ALLOWED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


@app.get("/")
@app.get("/health")
async def health_check():
    """Liveness probe for Hugging Face Spaces and any upstream load balancer."""
    return {"status": "ok", "service": "PoseCoach Overlay API", "version": "1.0.0"}


def _cleanup(paths: list[str | None]) -> None:
    """Delete temp files silently. Called as a background task so cleanup
    happens after the response has finished streaming, not before."""
    for path in paths:
        if not path:
            continue
        try:
            Path(path).unlink(missing_ok=True)
        except OSError:
            pass


@app.post("/api/generate_overlay")
@limiter.limit("10/minute")
async def generate_overlay(
    request: Request,
    file: UploadFile,
    background_tasks: BackgroundTasks,
) -> FileResponse:
    """
    Accept a reference photo and return a transparent neon-glow silhouette PNG
    ready to overlay on the Flutter app's live camera feed.
    """
    logger.info("Incoming overlay request")

    # Flutter's multipart encoder sometimes sends "application/octet-stream"
    # even for valid JPEGs. We accept it — just log a note so we have a trail
    # if something breaks.
    if (
        file.content_type not in _ALLOWED_MIME
        and file.content_type not in {"application/octet-stream", "application/x-www-form-urlencoded"}
    ):
        logger.warning("Non-standard MIME type: %s — proceeding anyway", file.content_type)

    raw_suffix = Path(file.filename or "upload.jpg").suffix.lower()
    safe_input_suffix = raw_suffix if raw_suffix in _ALLOWED_SUFFIXES else ".jpg"

    file_contents = bytearray()
    try:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            file_contents.extend(chunk)
            if len(file_contents) > _MAX_UPLOAD_BYTES:
                limit_mb = _MAX_UPLOAD_BYTES // (1024 * 1024)
                logger.warning("Upload rejected — exceeds %d MB limit", limit_mb)
                raise HTTPException(
                    status_code=413,
                    detail=f"File too large. Maximum allowed size is {limit_mb} MB.",
                )
    finally:
        await file.close()

    if len(file_contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    logger.info("Received %.1f KB (type=%s)", len(file_contents) / 1024, file.content_type)

    input_path = None
    output_path = None
    try:
        # Close the handles immediately after writing. On Windows, keeping them
        # open while OpenCV or TFLite tries to read the same path causes silent
        # failures because the OS locks the file.
        temp_in = NamedTemporaryFile(delete=False, suffix=safe_input_suffix)
        input_path = temp_in.name
        try:
            temp_in.write(bytes(file_contents))
        finally:
            temp_in.close()

        temp_out = NamedTemporaryFile(delete=False, suffix=".png")
        output_path = temp_out.name
        temp_out.close()

    except Exception:
        _cleanup([input_path, output_path])
        raise

    logger.info("Starting silhouette generation...")
    try:
        generate_transparent_overlay(input_path, output_path)
        logger.info("Silhouette generated successfully")
    except Exception:
        logger.error("Silhouette generation failed:\n%s", traceback.format_exc())
        _cleanup([input_path, output_path])
        raise HTTPException(status_code=500, detail="Overlay generation failed.")

    background_tasks.add_task(_cleanup, [input_path, output_path])

    logger.info("Sending silhouette response")
    return FileResponse(
        output_path,
        media_type="image/png",
        filename="transparent_silhouette.png",
        background=background_tasks,
    )


@app.post("/api/mask-corrections")
@limiter.limit("20/minute")
async def save_mask_correction(
    request: Request,
    device_id: str = Form(...),
    confidence: str = Form("0.0"),
    timestamp: str = Form(...),
    user_edited: str = Form("true"),
    original_image: UploadFile = File(...),
    ai_mask: UploadFile = File(...),
    corrected_mask: UploadFile = File(...),
):
    """
    Store a user-corrected mask alongside the original photo and the AI's first
    attempt. These triplets are our training data for improving segmentation
    quality over time. Files are grouped by device_id for easy tracing.
    """
    logger.info(
        "Mask correction upload — device=%s confidence=%s time=%s",
        device_id, confidence, timestamp,
    )

    out_dir = Path("data/corrections") / device_id
    out_dir.mkdir(parents=True, exist_ok=True)

    # Colons and dots in ISO timestamps aren't safe as filename characters
    # on all filesystems, so swap them out before using the timestamp as a prefix.
    ts_clean = timestamp.replace(":", "-").replace(".", "-")

    orig_path = out_dir / f"{ts_clean}_original.jpg"
    ai_path   = out_dir / f"{ts_clean}_ai_mask.png"
    corr_path = out_dir / f"{ts_clean}_corrected_mask.png"

    with open(orig_path, "wb") as f:
        f.write(await original_image.read())
    with open(ai_path, "wb") as f:
        f.write(await ai_mask.read())
    with open(corr_path, "wb") as f:
        f.write(await corrected_mask.read())

    logger.info("Correction saved to %s", out_dir)
    return {"status": "ok", "message": "Mask correction saved successfully."}
