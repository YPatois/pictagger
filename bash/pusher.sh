#!/bin/bash
source vault/vault.sh
set -o noclobber

mkdir -p $LOCAL_SCRATCH_DIR

rm -f $LOCAL_SCRATCH_DIR/img_list.txt

# Gather image to process
ssh $DATA_WN "cd $IMG_SRC_DIR; find stick* -type f -iname '*.jpg'" | sed -e's#^./##' > $LOCAL_SCRATCH_DIR/img_list.txt

ssh $DATA_WN mkdir -p $IMG_SRC_DIR/metadata

# Gather already processed image list
ssh $DATA_WN "cd $IMG_SRC_DIR/metadata/; ls *.json" >> $LOCAL_SCRATCH_DIR/processed_list.txt


mkdir -p $LOCAL_SCRATCH_DIR/locks
mkdir -p $LOCAL_SCRATCH_DIR/inputs

function process_image {
    img=$1
    echo "Processing $img"
    # If there are too many images in the queue, wait
    MAX_QUEUE=10
    while [ `ssh $PROCESS_WN "ls $IMG_PROCESS_DIR/inputs | wc -l"` -ge $MAX_QUEUE ]; do
        echo -n "."
        sleep 10
    done
    echo

    imgbase=`basename $img`
    imgfull=`echo $img | tr '/.' '_'`
    scp $DATA_WN:$IMG_SRC_DIR/$img $LOCAL_SCRATCH_DIR/inputs/$imgbase
    #ssh $PROCESS_WN "mkdir -p $IMG_PROCESS_DIR/inputs"
    scp $LOCAL_SCRATCH_DIR/inputs/$imgbase $PROCESS_WN:$IMG_PROCESS_DIR/inputs/$imgfull
    # Change ownership
    ssh $PROCESS_WN "chown $PROCESS_USER:$PROCESS_USER $IMG_PROCESS_DIR/inputs/$imgfull"
    # Ensure upload is complete
    ssh $PROCESS_WN "touch $IMG_PROCESS_DIR/inputs/${imgfull}.ok"
}

for img in `cat $LOCAL_SCRATCH_DIR/img_list.txt`; do
    echo $img
    img_meta_data=`echo $img | tr '/.' '_'`".json"
    echo $img_meta_data

    # Check that the image has not already been processed (from list)
    if grep -q $img_meta_data $LOCAL_SCRATCH_DIR/processed_list.txt; then
        echo "Image already processed (from list)"
        imgbase=`basename $img`
        rm -f $LOCAL_SCRATCH_DIR/inputs/$img
        rm -f $LOCAL_SCRATCH_DIR/locks/$img_meta_data
        imgfull=`echo $img | tr '/.' '_'`
        continue
    fi

    # Check that the image has not already been processed (from server)
    ssh $DATA_WN "ls $IMG_SRC_DIR/metadata/$img_meta_data" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Image already processed (from server)"
        imgbase=`basename $img`
        rm -f $LOCAL_SCRATCH_DIR/inputs/$img
        rm -f $LOCAL_SCRATCH_DIR/locks/$img_meta_data
        imgfull=`echo $img | tr '/.' '_'`
        ssh $PROCESS_WN "rm -f $IMG_PROCESS_DIR/inputs/$imgfull"
        continue
    fi

    # Atomic lock on $LOCAL_SCRATCH_DIR/locks/$img_meta_data
    { > $LOCAL_SCRATCH_DIR/locks/$img_meta_data ; } &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Lock failed"
        continue
    fi

    # Process the image
    echo "Processing $img"
    process_image $img
done
