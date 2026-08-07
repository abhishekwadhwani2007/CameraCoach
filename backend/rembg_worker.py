"""
Standalone rembg worker – called as a subprocess by outline.py.
Runs in its own Python process so it never conflicts with TensorFlow's GPU context.

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

        # CPU-only ONNX provider – no CUDA conflict since TF is not loaded here
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

        # Remove background -> RGBA PIL image
        result = remove(pil_img, session=session)

        # Extract alpha as grayscale mask
        alpha = np.array(result)[:, :, 3]          # 0-255

        # Resize to match original image dimensions
        H, W = img_bgr.shape[:2]
        alpha = cv2.resize(alpha, (W, H), interpolation=cv2.INTER_LINEAR)
        mask  = (alpha > 127).astype('uint8') * 255

        cv2.imwrite(output_path, mask)
        print(f"[rembg_worker] mask saved -> {output_path}", flush=True)
        sys.exit(0)

    except Exception as e:
        print(f"[rembg_worker] ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
