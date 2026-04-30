#!/bin/bash
source vault/vault.sh
set -o noclobber

mkdir -p $IMG_PROCESS_DIR/vlink

echo "Starting..."
# Watch for new images to process using inotifywait
inotifywait -m -e create -e moved_to -e delete $IMG_PROCESS_DIR/inputs | while read path action file; do
    # If a file is deleted, remove it from the queue
    if [ "$action" == "DELETE" ]; then
        rm -f $IMG_PROCESS_DIR/vlink/${file}.jpg
    else
        # Test if file is jpg, from magic, not extension
        if file $IMG_PROCESS_DIR/inputs/$file | grep -q JPEG; then
            echo "New image detected: $file"
            ln -s $IMG_PROCESS_DIR/inputs/$file $IMG_PROCESS_DIR/vlink/${file}.jpg
        else
            echo "File is not jpg: $file"
        fi
    fi
done
