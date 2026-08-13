# Deploying CameraCoach Backend to Render

This step-by-step guide walks you through deploying the **CameraCoach** FastAPI backend to Render using Docker. Render has an excellent free tier for Web Services and deploys directly from your GitHub repository.

---

## 🚀 Quick Overview

- **Host**: Render (render.com)
- **Service Type**: Web Service (Docker)
- **Deployment**: Automatic from GitHub
- **Port Handling**: Render automatically injects the `$PORT` environment variable.

---

## 📋 Step-by-Step Deployment Instructions

### Step 1: Ensure Your Code is on GitHub

Since Render deploys directly from your repository, make sure all your backend files are pushed to your GitHub repo (including `backend/Dockerfile`, `backend/requirements.txt`, etc.).

### Step 2: Create a Render Account

1. Go to [Render](https://render.com/) and create a free account (you can sign up with GitHub).
2. Log into your Render dashboard.

### Step 3: Create a New Web Service

1. On the Render Dashboard, click **New** and select **Web Service**.
2. Select **Build and deploy from a Git repository**.
3. Connect your GitHub account and select your `CameraCoach` repository.
4. On the deployment configuration page, set the following:
   - **Name**: `posecoach-api` (or your preferred name)
   - **Region**: Choose the one closest to you.
   - **Branch**: `main`
   - **Root Directory**: `backend` (This is very important! It tells Render to look for the Dockerfile inside the backend folder).
   - **Environment**: **Docker**
   - **Instance Type**: **Free** (If you don't see Free, make sure you don't have a database or other paid service attached, but the Free tier is available for standard Web Services).
5. Click **Create Web Service**.

---

### Step 4: Monitor Building & Container Startup

1. Render will automatically read your `Dockerfile` and start building the container.
2. You can watch the progress in the **Logs** window on the Render dashboard.
3. The build might take a few minutes as it installs Python and the necessary dependencies.
4. When it finishes, Render will start the server and you'll see a green "Live" status.

---

### Step 5: Verify the Live Endpoint

Render will give you a public URL (e.g., `https://posecoach-api.onrender.com`).

Test the endpoint:

- **Health Check**:
  Open your browser or use curl:
  ```bash
  curl https://posecoach-api.onrender.com/health
  ```
  *Expected Output:*
  ```json
  {"status":"ok","service":"PoseCoach Overlay API","version":"1.0.0"}
  ```

---

### Step 6: Update Mobile App Configuration

In your Flutter app, update `.env.json` or your API service configuration with your live Render URL:

```json
{
  "BACKEND_URL": "https://posecoach-api.onrender.com"
}
```

---

## 💤 Note on Render's Free Tier
Free web services on Render spin down after 15 minutes of inactivity. When the next request comes in, the service spins back up, which can cause a delay of 30-60 seconds for that first request. If this becomes an issue for your app's user experience, you can upgrade to Render's starter tier ($7/month) to keep it awake permanently.
