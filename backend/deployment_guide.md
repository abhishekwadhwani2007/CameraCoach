# Free backend deployment (Render)

The backend is configured as a Render Blueprint in the repository root (`render.yaml`). It uses the free web service plan, which costs $0 and spins down after 15 minutes without requests. The first request after an idle period can take around a minute to respond. Render currently documents 512 MB RAM for a free service, so the Docker image uses the smaller `tflite-runtime` rather than full TensorFlow.

## Deploy

1. Push this repository to GitHub (including `render.yaml` and `backend/`).
2. Sign in to [Render](https://render.com), choose **New > Blueprint**, and connect the repository and branch.
3. Review the blueprint. Confirm the service plan is **Free**, then apply it.
4. Wait for the service to become Live. Render assigns a URL like `https://posecoach-api.onrender.com`.
5. Check `https://YOUR-SERVICE.onrender.com/health`; it should return `{"status":"ok","service":"PoseCoach Overlay API","version":"1.0.0"}`.
6. Update the ignored local `.env.json` with that URL, then rebuild/run Flutter with `flutter run --dart-define-from-file=.env.json`.

```json
{
  "BACKEND_URL": "https://YOUR-SERVICE.onrender.com"
}
```

For a release build, pass the same define: `flutter build apk --dart-define=BACKEND_URL=https://YOUR-SERVICE.onrender.com`.

## Important limits

- Free services sleep after inactivity; the first request may be slow. The app already falls back to on-device silhouette generation when the backend is unavailable.
- Uploaded correction files are stored on the service's temporary filesystem and can disappear on restart or redeploy. No paid persistent disk is configured.
- Keep the service on the **Free** plan. Do not add a paid disk or upgrade the instance if keeping hosting at $0 is the priority.
- Render cannot stop or delete the existing Google Cloud Run service. After confirming the new URL works, disable/delete the Cloud Run service and any unused paid resources or registries in Google Cloud to stop further charges.

## Local backend

For local development, install `backend/requirements.txt` and run from `backend/`:

```bash
uvicorn server:app --host 0.0.0.0 --port 8000
```

The source uses TensorFlow on platforms where `tflite-runtime` is unavailable, such as Windows. The container installs only `backend/requirements-render.txt` to fit the free service's memory budget.
