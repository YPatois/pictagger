#!/bin/bash
source vault/vault.sh
set -o noclobber

mkdir -p $IMG_PROCESS_DIR/vlink


function process_image {
    fileok=$1
    echo "Processing $fileok"
    # Check that the file ends with ".ok"
    if [[ $fileok != *.ok ]]; then
        echo "File does not end with .ok"
        return
    fi

    img=`echo $fileok | sed -e 's/\.ok$//'`
    file $IMG_PROCESS_DIR/inputs/$img  | grep -q JPEG &> /dev/null
    if [ $? -eq 0 ]; then
        echo "New image detected: $img"
        ln -s $IMG_PROCESS_DIR/inputs/$img $IMG_PROCESS_DIR/vlink/${img}.jpg
    else
        echo "File is not jpg: $img"
    fi
}


echo "Starting..."
# Watch for new images to process using inotifywait
inotifywait -m -e create -e moved_to -e delete $IMG_PROCESS_DIR/inputs | while read path action file; do
    # If a file is deleted, remove it from the queue
    if [ "$action" == "DELETE" ]; then
        echo "File deleted: $file"
        rm -f $IMG_PROCESS_DIR/vlink/${file}.jpg
    else
        process_image $file
    fi
done
