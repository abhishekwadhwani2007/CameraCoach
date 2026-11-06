# 🛠️ CameraCoach — Engineering Lessons & Debugging Log

## 🛠️ Issues We Faced — And How We Solved Them

This is the honest development log. Every entry here cost us real time to figure out. We're writing it down so the next person — or future us — doesn't have to start from zero.

---

### 1. The original concept was impossible to communicate without tooling

The whole idea started with a frustration: you have a pose in mind, but no way to show it to the person holding the camera. You gesture, you mime, you show them a reference photo on your phone — and they still don't get it. We spent a while trying to work around this with verbal instructions and physical demonstrations before accepting that the real solution was a tool, not better communication. That became CameraCoach.

---

### 2. The stick-figure skeleton looked like something from 2015

Our first working prototype overlaid a wireframe skeleton — joints connected by lines — on the camera feed. It technically conveyed the pose, but it looked terrible and obscured the actual frame. Around the same time we noticed flagship phones shipping AI camera modes with full-body silhouette guides: soft, translucent glowing outlines that you could see through. That was the look we needed. We scrapped the skeleton and rebuilt the overlay pipeline around a transparent PNG approach with a neon glow effect rendered on the Python side.

---

### 3. Clean silhouette extraction turned out to be genuinely hard

Getting a good silhouette from an arbitrary user photo — different lighting, busy backgrounds, varied clothing, all body types — was the hardest single problem in the project. GrabCut alone was too noisy on photos with complex backgrounds. A plain segmentation model was inconsistent on different body types. We ended up layering three techniques: TFLite pose landmarks to establish where the body is, GrabCut initialised with those landmark hints to do the foreground/background cut, and then an edge-detection + Gaussian blur pass to produce the neon glow effect. None of them worked reliably alone. Together they covered most real-world cases.

---

### 4. The backend was buffering entire uploads into memory

The naive implementation used `await file.read()` — which reads the complete upload into RAM before doing anything with it. On a busy connection or a large photo, this silently caused timeouts and memory pressure. We rewrote the upload handling to read in 1 MB chunks and reject immediately if the total exceeds 10 MB:

```python
while True:
    chunk = await file.read(1024 * 1024)
    if not chunk:
        break
    file_contents.extend(chunk)
    if len(file_contents) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, ...)
```

The server now rejects an oversized file after seeing the first 11 MB — the rest of the payload is never touched.

---

### 5. Temp files silently failed on Windows

After the upload, we write the image to a temp file and pass the path to the OpenCV/TFLite pipeline. On Windows, `NamedTemporaryFile` holds the file handle open by default. OpenCV and TFLite then try to open the same path from a second handle — which Windows silently refuses. No exception. Just empty or corrupt output with no obvious cause. The fix was to close the temp file immediately after writing, before handing the path to anything else:

```python
temp_in = NamedTemporaryFile(delete=False, suffix=safe_input_suffix)
temp_in.write(bytes(file_contents))
temp_in.close()  # release the handle before CV reads it
```

---

### 6. The overlay disappeared entirely after a refactor pass *(the big one)*

A cleanup pass removed two widget properties from `viewfinder.dart` that looked like they were doing nothing. The app compiled. The app ran. The silhouette overlay stopped appearing completely on real devices. The simulator showed no difference. It took a full debugging session to trace it back.

Two lines are load-bearing for the overlay and must never be removed:

```dart
Transform.scale(
  scale: 1.15,                             // tuned to fill viewfinder without overflowing frame edges
  child: Image.file(
    overlayFile,
    key: ValueKey(referenceOutlinePath),   // without this Flutter reuses the old widget on path change
  ),
)
```

Both properties were restored. Everything came back immediately. This one is documented here permanently as a warning.

---

### 7. The image cache showed the old overlay after a reference change

Even after the `ValueKey` fix above, there was a separate caching issue: the Flutter image widget was sometimes still showing the previous silhouette after a user replaced their reference photo. The root cause was Flutter's image cache holding on to the old decoded image keyed by file path. The path hadn't changed (we were overwriting the same file), so the cache never invalidated. We added explicit cache eviction whenever the overlay updates:

```dart
imageCache.evict(FileImage(File(referenceOutlinePath)));
```

After that, the new overlay always appeared immediately.

---

### 8. The app crashed when the backend wasn't reachable

If the server was down, or the device lost LAN connectivity mid-session, the overlay request failed with an unhandled exception and the app either crashed or hung on a loading screen. The fix was `SilhouetteGenerator` — a fully on-device fallback that draws a basic silhouette from ML Kit pose landmarks without any network call. Backend failure now gracefully degrades to the on-device path. The coaching session continues; the overlay just looks simpler.

---

### 9. Saving a corrected mask was blocking the main UI flow

Users can manually draw corrections on the AI-generated mask before saving a reference. Those corrections are uploaded to the backend as training data. In the original implementation, the app waited for the upload to finish before allowing the user to continue — which meant any network latency was directly visible as a freeze. We made the upload fire-and-forget: the correction is queued in the background, failures are logged, and the UI moves on immediately regardless of what happens on the network.

---

### 10. The CORS configuration was technically invalid

`backend/server.py` had `allow_origins=["*"]` combined with `allow_credentials=True`. This combination is explicitly forbidden by the CORS specification and rejected by all modern browsers — credentials cannot be sent with a wildcard origin. For a LAN-only mobile app it didn't matter in practice (mobile HTTP clients don't enforce CORS), but it was wrong and would have caused real problems the moment a browser client was added. Fixed to `allow_credentials=False`.

---

### 11. User-controlled input was used directly as a filesystem path

The `/api/mask-corrections` endpoint used the `device_id` form field directly as a folder name: `Path("data/corrections") / device_id`. A device ID of `../../etc` would have written files outside the intended directory. We sanitised it with a strict regex before it touches the filesystem:

```python
safe_device_id = re.sub(r"[^\w\-]", "_", device_id)[:64]
out_dir = Path("data/corrections") / safe_device_id
```

---

### 12. The corrections endpoint had no upload size limit

The `/api/generate_overlay` endpoint had chunked reading with a 10 MB cap. The `/api/mask-corrections` endpoint — which accepts three files per request — used bare `await upload.read()` with no limit at all. We brought it in line with the same bounded helper used by the overlay endpoint. Each of the three correction files is now capped at 10 MB individually.

---

### 13. Log output crashed on Windows terminals

Python's default encoding on Windows stdout is `cp1252`. Any unicode character in a log message — an em-dash, a degree symbol, even some emoji from image metadata — caused a `UnicodeEncodeError` and killed the server process. The fix is two lines at the very top of `server.py`, before any logging is initialised:

```python
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")
```

---

### 14. Sensitive files and large build artifacts were at risk of being committed

`.env.json` (which contains the local backend IP), Firebase config files, and gigabytes of build output were all present locally. A drag-and-drop upload to GitHub — which bypasses `.gitignore` — could have committed all of them. We audited and hardened `.gitignore` to exclude all of these explicitly:

| File / Folder | Why it must stay out of Git |
|---------------|----------------------------|
| `.env.json` | Contains your local backend IP address |
| `android/app/google-services.json` | Firebase credentials |
| `ios/Runner/GoogleService-Info.plist` | Firebase credentials |
| `build/` | ~2.2 GB of compiled output |
| `.dart_tool/` | Generated tooling metadata |
| `android/.gradle/`, `android/.kotlin/` | Gradle and Kotlin caches |
| `backend/__pycache__/` | Python bytecode cache |
| `backend/data/corrections/` | User-submitted training images — private data |

> **Always use Git from the terminal or GitHub Desktop.** Drag-and-drop uploads to GitHub Web skip `.gitignore` entirely.

---

