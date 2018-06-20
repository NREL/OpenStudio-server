import os
import boto3
import re
import requests

try:
    access = os.environ['AWS_ACCESS_KEY_ID']
    secret = os.environ['AWS_SECRET_ACCESS_KEY']
except KeyError as e:
    raise 'ERROR: needed environment variable is not set: {}'.format(e.stderr)


def get_latest_openstudio_version_from_s3():
    # Now that we have the required artifacts, we boot up the AWS library and download the latest amis.json
    s3 = boto3.client('s3')

    all_content = []
    paginator = s3.get_paginator('list_objects')
    page_iterator = paginator.paginate(Bucket='openstudio-builds')

    for page in page_iterator:
        print("Requesting data from s3")
        all_content += page['Contents']

    pattern = re.compile("\d*\.\d*\.\d*\/OpenStudio")
    for content in all_content:
        if pattern.match(content['Key']):
            print(content['Key'])
        else:
            del content

    all_content = sorted(all_content, key=lambda k: k['LastModified'], reverse=True)

    for content in all_content:
        print(content)

    latest = all_content[0]['Key']
    match = re.search('OpenStudio-(\d*\.\d*\.\d*)\.(.*)-', latest)
    ver = match.group(1)
    sha = match.group(2)

    return [
        ver,
        sha,
        "https://s3.amazonaws.com/openstudio-builds/%s/OpenStudio-%s.%s-Linux.deb" % (ver, ver, sha)
    ]

def check_dockerhub_published(repo, version):
    r = requests.get('https://hub.docker.com/r/nrel/openstudio-server/tags/')


if __name__ == '__main__':
    print("Latest version of OpenStudio from S3 is:")
    print("  %s" % get_latest_openstudio_version_from_s3())
    print("")
    print("Checking Docker Hub")
