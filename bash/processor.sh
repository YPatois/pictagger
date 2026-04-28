#!/bin/bash
source vault/vault.sh
set -o noclobber

mkdir -p $IMG_PROCESS_DIR
mkdir -p $IMG_PROCESS_DIR/inputs
mkdir -p $IMG_PROCESS_DIR/reduced
mkdir -p $IMG_PROCESS_DIR/outputs
mkdir -p $IMG_PROCESS_DIR/locks

# Create a named pipe to connect to python script
#rm -f image_pipe
#mkfifo image_pipe

# Start the python script
#../python/pictager.py image_pipe 2>&1 | tee $IMG_PROCESS_DIR/image_pipe.log &

function process_image {
    fileok=$1
    echo "Processing $fileok"
    # Check that the file ends with ".ok"
    if [[ $fileok != *.ok ]]; then
        echo "File does not end with .ok"
        return
    fi
    img=`echo $fileok | sed -e 's/\.ok$//'`
    img_meta_data="${img}.json"
    rm -f $IMG_PROCESS_DIR/inputs/$fileok

    # Atomic lock on $IMG_PROCESS_DIR/locks/$img
    { > $IMG_PROCESS_DIR/locks/$img_meta_data ; } &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Lock failed. Image is already being processed."
        return
    fi

    # Reduce the image
    convert $IMG_PROCESS_DIR/inputs/$img -resize 900x900 $IMG_PROCESS_DIR/reduced/$img

    # Generate metadata
    echo "$IMG_PROCESS_DIR/reduced/$img $IMG_PROCESS_DIR/metadata/$img_meta_data"
    echo "$IMG_PROCESS_DIR/reduced/$img $IMG_PROCESS_DIR/metadata/$img_meta_data" > "image_pipe"

    okfile=$IMG_PROCESS_DIR/metadata/${img}.ok
    # Wait for the metadata to be generated
    echo "Waiting for metadata to be generated"
    while [ ! -f "$okfile" ]; do
        echo -n "."
        sleep 1
    done
    echo
    echo "Metadata generated."

    rm -f $IMG_PROCESS_DIR/inputs/$img
    rm -f $IMG_PROCESS_DIR/reduced/$img
    rm -f $IMG_PROCESS_DIR/locks/$img_meta_data
    rm -f $okfile

    # Mv metadata to outputs
    mv $IMG_PROCESS_DIR/metadata/$img_meta_data $IMG_PROCESS_DIR/outputs/

    echo "Finished processing $img"
}

function process__all_images {
    for img in `ls $IMG_PROCESS_DIR/inputs`; do
        process_image $img
    done 
}

echo "Starting..."
# Watch for new images to process using inotifywait
inotifywait -m -e create -e moved_to $IMG_PROCESS_DIR/inputs | while read path action file; do
    echo "New image detected: $file"
    process__all_images
done
