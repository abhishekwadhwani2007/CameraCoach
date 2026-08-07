# Contributing to CameraCoach

Thanks for taking a look at the code. Before you change anything, please read this — it'll save you from breaking the one thing that matters most.

---

## The one rule that overrides everything else

**Never touch the live overlay, pose matching, or auto-capture pipeline without a full plan and explicit approval.**

These features took months to get right. A previous AI-assisted cleanup silently broke the overlay by removing two lines that looked redundant but weren't. The app compiled fine, but the silhouette disappeared entirely on device. See the [What Broke Once](README.md#-what-broke-once-and-how-we-fixed-it) section in the README for the full story.

---

## Sacred files — hands off unless you have a plan

These files contain the live camera pipeline. Do not edit them without:
1. Reading every line you plan to change
2. Understanding exactly why it's there
3. Writing out what you're changing and why, and getting a second pair of eyes on it
4. Testing on a **real physical device** — the simulator will not catch overlay bugs

| File | Why it's sacred |
|------|----------------|
| `lib/features/live_session/live_coaching_screen.dart` | Camera init, pose stream, auto-capture state machine |
| `lib/features/live_session/widgets/viewfinder.dart` | Overlay rendering — the `Transform.scale` and `ValueKey` here are load-bearing |
| `lib/services/pose_comparison_service.dart` | Joint angle scoring and cosine similarity — the match % comes from here |
| `lib/services/pose_service.dart` | ML Kit pose detection wrapper |
| `lib/services/silhouette_generator.dart` | On-device TFLite silhouette fallback |

---

## Safe zones — fine to edit with care

These files are lower risk. Standard caution applies — no logic changes without testing.

| File / Area | Notes |
|-------------|-------|
| `lib/features/home/home_screen.dart` | UI strings, permission dialogs |
| `lib/features/onboarding/onboarding_screen.dart` | Onboarding copy and flow |
| `lib/features/review/` | Capture review screen, pose confirmation |
| `lib/core/constants.dart` | Comment changes only — never change values without understanding what uses them |
| `lib/widgets/` | Reusable UI components — grep for callers before removing anything |
| `backend/server.py` | FastAPI endpoint — keep the `/api/generate_overlay` route stable |
| `README.md` | Always welcome |

---

## Before removing any code

1. Run a grep across the whole `lib/` tree for the symbol name
2. Confirm it has zero callers
3. Remove it — then test

```bash
# Example
grep -r "MyWidgetName" lib/
```

If it shows up anywhere outside its own definition, it's not dead code.

---

## Commit message style

Write commit messages like a developer talking to their future self — short summary on the first line, then a plain-English explanation of what changed and why. Avoid stiff changelog language.

**Good:**
```
fix: stop the overlay disappearing after reference change

The ValueKey on the overlay Image.file was missing after a cleanup pass.
Without it Flutter reuses the old widget and the new silhouette never shows.
```

**Avoid:**
```
Update viewfinder.dart to implement overlay fix
```

---

## Testing checklist after any change near the camera pipeline

Always test this flow on a real Android or iOS device before pushing:

- [ ] Upload a reference photo → silhouette overlay appears on the coaching screen
- [ ] Move in front of the camera → match percentage updates in real time
- [ ] Hold the pose at 97%+ for several frames → 3-second countdown starts
- [ ] Let the countdown finish → photo is taken and saved to the gallery
- [ ] Tap Cancel during countdown → coaching resumes normally

If any of these fail, **do not push**.

---

Built with ❤️ by **Abhishek Wadhwani** & Team
