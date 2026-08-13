"""
Inactive rembg fallback worker.

The active overlay pipeline in outline.py does not call this file today. It is
kept as a small subprocess-based fallback for future segmentation experiments,
where rembg can run without sharing TensorFlow's runtime state.

Usage:
    python rembg_worker.py <input_image_path> <output_mask_path>

Outputs a grayscale PNG mask (255 = foreground, 0 = background).
Exits 0 on success, 1 on failure.
"""
import sys
import os

def main():
    if len(sys.argv) != 3:
        print("Usage: rembg_worker.py <input_image_path> <output_mask_path>", file=sys.stderr)
        sys.exit(1)

    input_path  = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(input_path):
        print(f"Input not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    try:
        import cv2
        import numpy as np
        from PIL import Image
        from rembg import remove, new_session

        # Keep rembg on CPU so this worker stays isolated from TensorFlow/GPU
        # state if the fallback path is re-enabled later.
        session = new_session(
            'u2net_human_seg',
            providers=['CPUExecutionProvider'],
        )

        img_bgr = cv2.imread(input_path)
        if img_bgr is None:
            print(f"Cannot read image: {input_path}", file=sys.stderr)
            sys.exit(1)

        rgb     = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb)

        # rembg returns an RGBA image; the alpha channel is the foreground mask
        # outline.py expects from this worker.
        result = remove(pil_img, session=session)

        alpha = np.array(result)[:, :, 3]          # 0-255

        # Match the original image size so callers can combine this mask with
        # pose landmarks in the same coordinate space.
        H, W = img_bgr.shape[:2]
        alpha = cv2.resize(alpha, (W, H), interpolation=cv2.INTER_LINEAR)
        mask  = (alpha > 127).astype('uint8') * 255

        if not cv2.imwrite(output_path, mask):
            raise RuntimeError(f"Failed to write mask: {output_path}")
        print(f"[rembg_worker] mask saved -> {output_path}", flush=True)
        sys.exit(0)

    except Exception as e:
        print(f"[rembg_worker] ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
