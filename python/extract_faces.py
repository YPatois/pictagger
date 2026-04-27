#!/usr/bin/env python3

import cv2
import os
from pathlib import Path
from insightface.app import FaceAnalysis

# Initialize face detection
app = FaceAnalysis(name='buffalo_l')
app.prepare(ctx_id=0, det_size=(640, 640))

def extract_and_save_faces(input_dir, output_dir):
    """
    Detects faces in images from `input_dir`, crops them, and saves to `output_dir`.
    Args:
        input_dir (str): Directory containing input images.
        output_dir (str): Directory to save cropped faces.
    """
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    for img_file in os.listdir(input_dir):
        if not img_file.lower().endswith(('.jpg', '.jpeg', '.png')):
            continue

        img_path = os.path.join(input_dir, img_file)
        img = cv2.imread(img_path)
        if img is None:
            print(f"Failed to read {img_file}")
            continue

        faces = app.get(img)
        if not faces:
            print(f"No faces detected in {img_file}")
            continue

        for i, face in enumerate(faces):
            bbox = face.bbox.astype(int)
            x1, y1, x2, y2 = bbox
            face_crop = img[y1:y2, x1:x2]

            # Save cropped face
            output_path = os.path.join(output_dir, f"{Path(img_file).stem}_face_{i}.jpg")
            cv2.imwrite(output_path, face_crop)
            print(f"Saved face {i} from {img_file} to {output_path}")

if __name__ == "__main__":
    input_directory = "./input"
    output_directory = "./output"
    extract_and_save_faces(input_directory, output_directory)
