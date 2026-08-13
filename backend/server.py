import sys
import traceback
from pathlib import Path
from tempfile import NamedTemporaryFile

# Keep Windows console logging UTF-8 safe.
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from outline import generate_transparent_overlay


limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="PoseCoach Overlay API")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

# Validate the client-provided type before processing the upload.
_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}

_ALLOWED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


@app.get("/")
@app.get("/health")
async def health_check():
    """Health check endpoint for cloud load balancers and container monitoring."""
    return {"status": "ok", "service": "PoseCoach Overlay API", "version": "1.0.0"}



def _cleanup(paths: list[str | None]) -> None:
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
    print("\n=== NEW REQUEST ===", flush=True)

    # Some mobile upload stacks send a generic type even for valid images.
    if file.content_type not in _ALLOWED_MIME and file.content_type != "application/octet-stream" and file.content_type != "application/x-www-form-urlencoded":
        print(f"[WARN] Non-standard MIME type: {file.content_type} (proceeding)", flush=True)

    raw_suffix = Path(file.filename or "upload.jpg").suffix.lower()
    safe_input_suffix = raw_suffix if raw_suffix in _ALLOWED_SUFFIXES else ".jpg"

    # Read in chunks so oversized uploads are rejected before loading fully.
    file_contents = bytearray()
    try:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break

            file_contents.extend(chunk)
            if len(file_contents) > _MAX_UPLOAD_BYTES:
                print(
                    f"[REJECT] Upload exceeds {_MAX_UPLOAD_BYTES // (1024*1024)} MB limit",
                    flush=True,
                )
                raise HTTPException(
                    status_code=413,
                    detail=f"File too large. Maximum allowed size is {_MAX_UPLOAD_BYTES // (1024*1024)} MB.",
                )
    finally:
        await file.close()

    if len(file_contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    print(f"[OK] Received {len(file_contents):,} bytes (type={file.content_type})", flush=True)

    input_path = None
    output_path = None
    try:
        # Close temp handles before processing. On Windows, open
        # NamedTemporaryFile handles can block OpenCV from reading/writing them.
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

    print("[START] generate_transparent_overlay() ...", flush=True)
    try:
        generate_transparent_overlay(input_path, output_path)
        print("[OK] Overlay generated successfully", flush=True)
    except Exception:
        print("[CRASH] Exception in generate_transparent_overlay():", flush=True)
        print(traceback.format_exc(), flush=True)
        _cleanup([input_path, output_path])
        raise HTTPException(status_code=500, detail="Overlay generation failed.")

    # The response streams the generated PNG, so cleanup runs after send.
    background_tasks.add_task(_cleanup, [input_path, output_path])

    print(f"[SEND] Dispatching FileResponse -> {output_path}", flush=True)
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
    print("\n=== MASK CORRECTION UPLOAD ===", flush=True)
    print(f"[CORRECTION] Device: {device_id}, Confidence: {confidence}, Time: {timestamp}", flush=True)

    out_dir = Path("data/corrections") / device_id
    out_dir.mkdir(parents=True, exist_ok=True)
    ts_clean = timestamp.replace(":", "-").replace(".", "-")

    orig_path = out_dir / f"{ts_clean}_original.jpg"
    ai_path = out_dir / f"{ts_clean}_ai_mask.png"
    corr_path = out_dir / f"{ts_clean}_corrected_mask.png"

    with open(orig_path, "wb") as f:
        f.write(await original_image.read())
    with open(ai_path, "wb") as f:
        f.write(await ai_mask.read())
    with open(corr_path, "wb") as f:
        f.write(await corrected_mask.read())

    print(f"[OK] Saved correction files to {out_dir}", flush=True)
    return {"status": "ok", "message": "Mask correction saved successfully."}

