#!/usr/bin/env python3

import ollama
from PIL import Image, ExifTags
import piexif
import json
import sys
from pathlib import Path
from datetime import datetime
import time

def extract_metadata_from_image(image_location: str):
    """Retrieve camera metadata: Capture Date and Lens Focal Length"""
    try:
        with Image.open(image_location) as img:
            exif_metadata = img._getexif()
            if not exif_metadata:
                return {"capture_date": None, "lens_focal": None}

            metadata = {}
            for tag_id, value in exif_metadata.items():
                tag_label = ExifTags.TAGS.get(tag_id, tag_id)

                if tag_label == "DateTimeOriginal":
                    metadata["capture_date"] = str(value)
                elif tag_label == "FocalLength":
                    if isinstance(value, tuple):
                        metadata["lens_focal"] = f"{value[0]}/{value[1]} mm" if value[1] != 0 else f"{value[0]} mm"
                    else:
                        metadata["lens_focal"] = f"{value} mm"

            return metadata

    except Exception as error:
        print(f"Notice: Metadata extraction failed: {error}")
        return {"capture_date": None, "lens_focal": None}

def process_image_with_metadata(image_location: str, output_path: str = None, 
    model: str = "qwen3.6:latest", write_back: bool = True):
    image_location = Path(image_location)
    if not image_location.exists():
        print(f"Error: File not found: {image_location}")
        return

    print(f"Analyzing: {image_location.name}")

    # Step 1: Retrieve original camera metadata
    metadata = extract_metadata_from_image(str(image_location))
    print("\n--- Original Metadata ---")
    print(f"Capture Date   : {metadata.get('capture_date') or 'Not Available'}")
    print(f"Lens Focal      : {metadata.get('lens_focal') or 'Not Available'}")

    # Step 2: Perform AI-based content analysis
    analysis_prompt = """Examine this image and provide ONLY a list of descriptive keywords in the following format:

        - listed
        - separated
        - keywords
        - expressing
        - content
        - like
        - landscape
        - sea
        - mountain
        - people
        - boat
        - shore
        - nude
        - sky
        - etc

Be as descriptive as possible, but only refers well identified objects."""

    print("\nRequesting AI analysis...")

    ai_response = ollama.chat(
        model=model,
        messages=[{
            'role': 'user',
            'content': analysis_prompt,
            'images': [str(image_location)]
        }],
        options={"temperature": 0.6, "num_ctx": 8192}
    )

    response_content = ai_response['message']['content'].strip()

    analysis_result = {}

    keywords = []
    kwddict={}
    for line in response_content.split("\n"):
        if line:
            keyword = line.strip('-').strip()
            if keyword:
                if not (keyword in kwddict):
                    kwddict[keyword] = 1
                    keywords.append(keyword)

    analysis_result["keywords"] = keywords
    analysis_result["capture_date"] = metadata.get("capture_date") or "Not Available"
    analysis_result["lens_focal"] = metadata.get("lens_focal") or "Not Available"

    print("\n--- AI Analysis Result ---")
    print(f"Keywords        : {', '.join(analysis_result['keywords'])}")
    print(f"Capture Date    : {analysis_result['capture_date']}")
    print(f"Lens Focal       : {analysis_result['lens_focal']}")

    # Write output as json:
    print(f"\nWriting output in {output_path}")
    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(analysis_result, indent=2, ensure_ascii=False))
    
    # Write OK file
    print("Writing OK file...")
    if write_back:
        with open(output_path.with_suffix(".ok"), "w") as ok_file:
            ok_file.write("OK")

def process_single_image(image_path: str, output_path: str = None):
    #print ("stuff")
    #return
    process_image_with_metadata(image_path, output_path=output_path, model="qwen3.6:latest", write_back=True)

def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py <fifo_path>")
        sys.exit(1)

    fifo_path = sys.argv[1]
    print("Using fifo path: " + fifo_path)

    while True:
        try:
            with open(fifo_path, "r") as fifo:
                print("Waiting for input...")
                for line in fifo:
                    line = line.strip()
                    if not line:
                        continue
                    print("Received: " + line)
                    image_path = line.split()[0].strip()
                    output_path = line.split()[1].strip()
                    if not image_path or not Path(image_path).exists():
                        print(f"Skipping: {image_path} (not found)")
                        continue
                    process_single_image(image_path, output_path=output_path)
                    print("Ready for next image...")

        except (KeyboardInterrupt, SystemExit):
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}. Reopening FIFO...")
            time.sleep(1)  # Avoid busy-waiting
    print("Done")
if __name__ == "__main__":
    main()
