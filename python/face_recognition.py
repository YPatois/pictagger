import cv2
import numpy as np
from insightface.app import FaceAnalysis
from pathlib import Path
import pickle
from sklearn.metrics.pairwise import cosine_similarity

# Database of known faces: identifier -> list of feature vectors (allows multiple images per person)
FACE_DATABASE = {}

# Initialize the face analysis pipeline
face_app = FaceAnalysis(name='buffalo_l')
face_app.prepare(ctx_id=0, det_size=(640, 640))

def extract_faces(image_path):
    """Extracts faces and their features from an image."""
    img = cv2.imread(str(image_path))
    if img is None:
        return []

    faces = face_app.get(img)
    results = []

    for face in faces:
        results.append({
            "bbox": face.bbox.astype(int).tolist(),
            "landmarks": face.landmark_2d_106.astype(int).tolist() if hasattr(face, 'landmark_2d_106') else None,
            "embedding": face.normed_embedding.tolist(),
            "score": float(face.det_score),
            "age": int(face.age) if hasattr(face, 'age') else None,
            "gender": "Male" if hasattr(face, 'gender') and face.gender == 1 else "Female"
        })
    return results

def add_face_to_database(image_location, identifier):
    """Adds a face to the database for future recognition."""
    detected_faces = extract_faces(image_location)
    if not detected_faces:
        print("No faces found in the provided image.")
        return

    # Select the face with the highest confidence score
    top_face = max(detected_faces, key=lambda entry: entry["score"])
    feature_vector = np.array(top_face["embedding"])

    if identifier not in FACE_DATABASE:
        FACE_DATABASE[identifier] = []
    FACE_DATABASE[identifier].append(feature_vector)

    print(f"Added face for {identifier} with feature vector shape {feature_vector.shape}")

def match_faces_in_image(image_location, similarity_threshold=0.5):
    """Matches faces in an image against the database."""
    detected_faces = extract_faces(image_location)
    recognition_results = []

    for face_entry in detected_faces:
        current_features = np.array(face_entry["embedding"]).reshape(1, -1)
        best_candidate = {"identifier": "Unknown", "match_score": 0.0}

        for person_id, stored_vectors in FACE_DATABASE.items():
            for stored_vector in stored_vectors:
                match_score = cosine_similarity(current_features, stored_vector.reshape(1, -1))[0][0]
                if match_score > best_candidate["match_score"]:
                    best_candidate = {"identifier": person_id, "match_score": match_score}

        if best_candidate["match_score"] > similarity_threshold:
            recognition_results.append({
                "identifier": best_candidate["identifier"],
                "match_score": round(best_candidate["match_score"], 4),
                "bounding_box": face_entry["bbox"]
            })
        else:
            recognition_results.append({
                "identifier": "Unknown",
                "match_score": round(best_candidate["match_score"], 4),
                "bounding_box": face_entry["bbox"]
            })

    return recognition_results

if __name__ == "__main__":
    # Example usage
    image_path = Path("path/to/image.jpg")
    faces = extract_faces(image_path)
    print("Detected Faces:", faces)

    # Example: Add a face to the database
    add_face_to_database(image_path, "person_1")

    # Example: Match faces in an image
    matches = match_faces_in_image(image_path)
    print("Recognition Results:", matches)
