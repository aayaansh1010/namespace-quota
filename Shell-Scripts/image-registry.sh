#!/bin/bash

# Define the output file
output_file="openshift_images_output.csv"

# Write the CSV header
echo "Namespace,ImageStream,Tag,Image" | tee $output_file

# 1. List images via ImageStreams
namespaces=$(oc get namespaces -o jsonpath='{.items[*].metadata.name}')

for ns in $namespaces; do
    imagestreams=$(oc get is -n $ns -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$imagestreams" ]; then
        echo "$ns,No ImageStreams found,,," | tee -a $output_file
    else
        for is in $imagestreams; do
            tags=$(oc get is $is -n $ns -o jsonpath='{.status.tags[*].tag}')

            if [ -z "$tags" ]; then
                echo "$ns,$is,No tags found,," | tee -a $output_file
            else
                for tag in $tags; do
                    image_ref=$(oc get is $is -n $ns -o jsonpath="{.status.tags[?(@.tag=='$tag')].items[0].dockerImageReference}")
                    echo "$ns,$is,$tag,$image_ref" | tee -a $output_file
                done
            fi
        done
    fi
done

# 2. List all images from the internal registry (for orphaned images)
echo "InternalRegistry,Orphaned Image,,Image" | tee -a $output_file

images=$(oc get images -o jsonpath='{.items[*].dockerImageReference}')

if [ -z "$images" ]; then
    echo "InternalRegistry,No orphaned images found,," | tee -a $output_file
else
    for image in $images; do
        echo "InternalRegistry,Orphaned Image,,$image" | tee -a $output_file
    done
fi

# 3. Send the CSV via email
echo "Please find the attached CSV report for OpenShift images." | mail -s "OpenShift Images Report" -a $output_file vsardana@volvocars.com
