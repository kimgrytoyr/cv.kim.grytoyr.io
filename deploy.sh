#!/bin/bash
distribution_id="E1B9KWNF6O30FL" # Cloudfront distribution ID
bucket_name="kim-grytoyr-io" # S3 bucket name

# Clean the public folder, Hugo doesn't do this for you
echo "Cleaning public folder.."
rm -rf ./public

# Build the website
echo "Building website.."
hugo >/dev/null

# Sync with S3 bucket. Delete from S3 if necessary, and only use file size for matching files
echo "Deploying to S3 bucket $bucket_name.."
aws s3 sync ./public s3://$bucket_name --delete --size-only > .sync.log

# Truncate temporary files
echo "Creating list of changed files.."
> .changed-files
> .paths

# Parse the log from S3 sync and remove everything but paths
while read -r line
do
    echo $line | sed "s/^.*$bucket_name//" | tr -d '[:blank:]' >> .changed-files
done < .sync.log

# Replace the newlines with spaces for --path flag
tr '\r\n' ' ' < .changed-files > .paths

# Check if .paths is empty
if [ ! -s .paths ]
then
    # No changes made
    echo "No changes, nothing to invalidate.."
else
    # Changes made. Invalidate changed paths in Cloudfront
    echo "Invalidating cache.."
    aws cloudfront create-invalidation --distribution-id $distribution_id --paths $(cat .paths) /index.html >/dev/null
fi

echo "Deployed!"
