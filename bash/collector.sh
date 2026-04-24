#!/bin/bash
source vault/vault.sh

mkdir -p $LOCAL_SCRATCH_DIR/outputs


function process_json {
    json=$1
    echo "Processing $json"
    # First ensure process is finished
    ssh $PROCESS_WN "ls $IMG_PROCESS_DIR/lock/$json" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Process not finished"
        return
    fi

    # Ensure json is not already processed
    ssh $DATA_WN "ls $IMG_SRC_DIR/metadata/$json" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Image already processed"
        img=`echo $json | cut -d '.' -f 1`
        ssh $PROCESS_WN "rm -f $IMG_PROCESS_DIR/inputs/$img"
        rm -f $LOCAL_SCRATCH_DIR/outputs/$json
        return
    fi

    # Copy json to data server
    scp $PROCESS_WN:$IMG_PROCESS_DIR/outputs/$json $DATA_WN:$IMG_SRC_DIR/metadata/$json

    # Change ownership
    ssh $DATA_WN "chown $DATA_USER:$DATA_USER $IMG_SRC_DIR/metadata/$json"

    # Remove img and json from process server
    ssh $PROCESS_WN "rm -f $IMG_PROCESS_DIR/inputs/$img"
    ssh $PROCESS_WN "rm -f $IMG_PROCESS_DIR/outputs/$json"
}

# Periodically check for new json
while true; do
    echo "Checking for new processed json..."
    ssh $PROCESS_WN "ls $IMG_PROCESS_DIR/outputs" > $LOCAL_SCRATCH_DIR/outputs.txt
    # If process returns in error, maybe the directory doesn't exist yet
    if [ $? -eq 0 ]; then
        for json in `cat $LOCAL_SCRATCH_DIR/outputs.txt`; do
            process_image $json
        done
    else
        echo "Directory not found..."
    fi
    sleep 10
done
