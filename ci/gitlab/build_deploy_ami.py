#!/usr/env/python

import os
from subprocess import Popen, PIPE, STDOUT
import argparse
import json
import signal
import boto3
import fileinput
import re
import sys


# A helper method for executing command line calls cleanly
def run_cmd(exec_str, description):
    p = Popen(exec_str, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE, close_fds=True, preexec_fn=os.setsid)
    pgid = os.getpgid(p.pid)

    def signal_handler(sig_type, _):
        if sig_type == signal.SIGINT:
            os.killpg(pgid, signal.SIGINT)
        sys.exit(1)

    signal.signal(signal.SIGINT, signal_handler)
    (stdout, stderr) = p.communicate(None)
    exit_code = p.returncode
    if exit_code is not 0:
        print '{} returned non-zero exit status. Returned status `{}`'.format(description, exit_code)
        if stdout != '':
            print 'STDOUT:'
            print stdout
        if stderr != '':
            print 'STDERR:'
            print stderr
        raise RuntimeError('Aborting due to previous failure')
    return stdout

# Define the CLI
parser = argparse.ArgumentParser()
parser.add_argument('-o', '--output_dir', default=os.getcwd(),
                    help='Absolute path to the directory to write the output log to')
parser.add_argument('-n', '--notes', default=None, help='Provide notes to be persisted in the amis.json entry')
parser.add_argument('-v', '--verbose', help='Verbose output', action='store_true')
parser.add_argument('--generated_by', default='GitLabCI', help='Set the Author metadata field')
parser.add_argument('--docker_version', default=None, help='Overwrite the docker version in the AMI')
parser.add_argument('--ami_version', default=None, help='Overwrite the AMI version')
parser.add_argument('--ami_extension', default=None, help='Overwrite the AMI version extension')
parser.add_argument('--dockerhub_repo', default=None, help='Release from a non-NREL DockerHub repository')
parser.add_argument('--write_json', help='Write AMI JSON specification to file instead of S3', action='store_true')
parser.add_argument('--disable_public', help='Do not make the AMI public', action='store_true')
parser.add_argument('--enable_custom_build', help='Flag to allow non-standard AMI release', action='store_true')
args = parser.parse_args()

# Parse ARGV
output_dir = args.output_dir
generated_by = args.generated_by
override_docker_version = args.docker_version
override_ami_version = args.ami_version
override_ami_extension = args.ami_extension
override_dockerhub_repo = args.dockerhub_repo
write_to_file = args.write_json
disable_public = args.disable_public
custom_enabled = args.enable_custom_build
notes = args.notes
verbose = args.verbose

if not custom_enabled:
    if generated_by is not 'GitLabCI':
        raise EnvironmentError('Cannot parse --generated_by, as custom builds is not enabled')
    if override_docker_version is not None:
        raise EnvironmentError('Cannot parse --docker_version, as custom builds is not enabled')
    if override_ami_version is not None:
        raise EnvironmentError('Cannot parse --ami_version, as custom builds is not enabled')
    if override_ami_extension is not None:
        raise EnvironmentError('Cannon prase --ami_extension, as custom builds is not enabled')
    if override_dockerhub_repo is not None:
        raise EnvironmentError('Cannot parse --dockerhub_repo, as custom builds is not enabled')
    if write_to_file:
        raise EnvironmentError('Cannot parse --write_json, as custom builds is not enabled')
    if disable_public:
        raise EnvironmentError('Cannot parse --disable_public, as custom builds is not enabled')

# Ensure the required environment variables exist
try:
    home = os.environ['HOME']
    access = os.environ['AWS_ACCESS_KEY_ID']
    secret = os.environ['AWS_SECRET_ACCESS_KEY']
except KeyError as e:
    raise 'ERROR: needed environment variable is not set: {}'.format(e.stderr)

# Get the docker version to use
template_path = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                             '../../docker/deployment/user_variables.json.template'))
with open(template_path) as f:
    docker_version = str(json.load(f)["docker_version"])
if override_docker_version is not None:
    if verbose:
        print 'Docker version being overwritten from `{}` to `{}`'.format(docker_version, override_docker_version)
    docker_version = override_docker_version

# Get the OpenStudioServer version and version extension to use
version_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../server/lib/openstudio_server/version.rb'))

cmd_call = 'ruby -r {} -e "puts OpenstudioServer::VERSION"'.format(version_path)
if verbose:
    print 'OSS version retrieval command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio Server version retrieval')
ami_version = stdout_str.strip()
if verbose:
    print 'OSS version retrieved is {}\n'.format(ami_version)
if override_ami_version is not None:
    if verbose:
        print 'AMI version being overwritten from `{}` to `{}`'.format(ami_version, override_ami_version)
    ami_version = override_ami_version

cmd_call = 'ruby -r {} -e "puts OpenstudioServer::VERSION_EXT"'.format(version_path)
if verbose:
    print 'OSS version extension retrieval command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio Server version extension retrieval')
ami_version_ext = stdout_str.strip()
if verbose:
    print 'OSS version extension retrieved is {}\n'.format(ami_version_ext)
if override_ami_extension is not None:
    if override_ami_extension[0] != '-':
        override_ami_extension = '-' + override_ami_extension.strip()
    if verbose:
        print 'AMI version extension being overwritten from `{}` to `{}`'.format(ami_version_ext,
                                                                                 override_ami_extension)
    ami_version_ext = override_ami_extension

# Write the packer user variables json file
defaults = {
    'generated_by': '',
    'docker_version': docker_version,
    'version': ami_version,
    'ami_version_extension': ami_version_ext
}
if generated_by is not 'GitLabCI':
    if verbose:
        print 'AMI author being overwritten from `GitLabCI` to `{}`'.format(generated_by)
defaults['generated_by'] = generated_by
variables_write_path = os.path.join(os.path.dirname(template_path), 'user_variables.json')
with open(variables_write_path, 'w') as f:
    json.dump(defaults, f)

# If using a custom DockerHub repo, change the docker images loaded into the AMI
if override_dockerhub_repo is not None:
    docker_config_path = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                                      '../../docker/deployment/scripts/aws_osserver_init.sh'))
    for line in fileinput.input(docker_config_path, inplace=1, backup='.bak'):
        line = re.sub('docker pull nrel', 'docker pull {}'.format(override_dockerhub_repo), line.rstrip())
        line = re.sub('docker tag nrel', 'docker tag {}'.format(override_dockerhub_repo), line)
        print(line)
    if verbose:
        print 'Replaced `nrel` with `{}` in docker pull and docker tag commands'.format(override_dockerhub_repo)

# Next we need to run packer and retrieve the new AMI ID
os.chdir(os.path.dirname(template_path))
os.environ['AWS_ACCESS_KEY'] = access
os.environ['AWS_SECRET_KEY'] = secret
packer_log = os.path.join(output_dir, 'build.log')
cmd_call = 'packer build -machine-readable -var-file=user_variables.json openstudio_server_docker_base.json 2>&1 | ' \
           'tee {}'.format(packer_log)
if verbose:
    print 'Packer command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'Packer')
if verbose:
    print 'STDOUT written to {}'.format(packer_log)
ami_id_line = stdout_str.split('\\n')[-2]
if ami_id_line.split(':')[0] != 'us-east-1':
    raise RuntimeError('Unexpected return from the packer script. Please review {}'.format(packer_log))
if ami_id_line.split(':')[1].strip()[0:4] != 'ami-':
    raise RuntimeError('Unexpected return from the packer script. Please review {}'.format(packer_log))
ami_id = ami_id_line.split(':')[1].strip()

# Now we retrieve the additional required fields for the amis.json file, starting with the server SHA
cmd_call = 'git log -n 1 | grep commit'
if verbose:
    print 'OpenStudio Server SHA retrieval command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio Server SHA retrieval')
server_sha = stdout_str.replace('commit', '').strip()
if verbose:
    print 'OpenStudio Server SHA retrieved is {}'.format(server_sha)

# Next we pull the openstudio-server container and parse out each version required
cmd_call = 'docker pull nrel/openstudio-server:{}'.format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker pull nrel', 'docker pull {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server container pull command is: {}'.format(cmd_call)
run_cmd(cmd_call, 'openstudio-server container retrieval')

# OpenStudio version and SHA
cmd_call = 'docker run nrel/openstudio-server:{} ruby -r openstudio -e "puts OpenStudio.openStudioLongVersion"'.\
    format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server OpenStudio version command is: {}'.format(cmd_call)
stdout_arr = run_cmd(cmd_call, 'OpenStudio version retrieval').split('\n')[-2].split('.')
os_version = stdout_arr[0] + '.' + stdout_arr[1] + '.' + stdout_arr[2]
os_sha = stdout_arr[3]
if verbose:
    print 'OpenStudio version retrieved is {}, with SHA {}'.format(os_version, os_sha)

# OpenStudio-Standards version
cmd_call = 'docker run nrel/openstudio-server:{} bundle exec ruby -e "require \'openstudio\'; require ' \
           '\'openstudio-standards\'; puts OpenstudioStandards::VERSION"'.format(defaults['version'] +
                                                                                 defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server OpenStudio-Standards version command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio-Standards version retrieval').split('\n')[-2]
standards_version = stdout_str.strip()
if verbose:
    print 'OpenStudio-Standards version retrieved is {}'.format(standards_version)

# OpenStudio-Analysis version
cmd_call = 'docker run nrel/openstudio-server:{} bundle exec ruby -e "require \'openstudio\'; require ' \
           '\'openstudio-analysis\'; puts OpenStudio::Analysis::VERSION"'.format(defaults['version'] +
                                                                                 defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server OpenStudio-Analysis version command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio-Analysis version retrieval').split('\n')[-2]
analysis_version = stdout_str.strip()
if verbose:
    print 'OpenStudio-Analysis version retrieved is {}'.format(analysis_version)

# OpenStudio-Workflow version
cmd_call = 'docker run nrel/openstudio-server:{} bundle exec ruby -e "require \'openstudio\'; require ' \
           '\'openstudio-workflow\'; puts OpenStudio::Workflow::VERSION"'.format(defaults['version'] +
                                                                                 defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server OpenStudio-Workflow version command is: {}'.format(cmd_call)
stdout_str = run_cmd(cmd_call, 'OpenStudio version retrieval').split('\n')[-2]
workflow_version = stdout_str.strip()
if verbose:
    print 'OpenStudio-Workflow version retrieved is {}'.format(workflow_version)

# EnergyPlus version
cmd_call = 'docker run nrel/openstudio-server:{} ruby -r openstudio -e "puts OpenStudio.energyPlusVersion"'.\
    format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server EnergyPlus version command is: {}'.format(cmd_call)
stdout_arr = run_cmd(cmd_call, 'EnergyPlus version retrieval').split('\n')[-2].split('.')
eplus_version = stdout_arr[0] + '.' + stdout_arr[1]
if verbose:
    print 'EnergyPlus version retrieved is {}'.format(eplus_version)

# Radiance version
cmd_call = 'docker run nrel/openstudio-server:{} /usr/Radiance/bin/rtrace -version'.\
    format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-server Radiance version command is: {}'.format(cmd_call)
stdout_arr = run_cmd(cmd_call, 'Radiance version retrieval').split('\n')[-2].split('.')
radiance_version = stdout_arr[0] + '.' + stdout_arr[1] + '.' + stdout_arr[2]
if verbose:
    print 'Radiance version retrieved is {}'.format(radiance_version)

# Next we pull the openstudio-rserve container and parse the R version
cmd_call = 'docker pull nrel/openstudio-rserve:{}'.format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker pull nrel', 'docker pull {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-rserve container pull command is: {}'.format(cmd_call)
run_cmd(cmd_call, 'openstudio-rserve container retrieval')

# R version
cmd_call = 'docker run nrel/openstudio-rserve:{} R --version'.\
    format(defaults['version'] + defaults['ami_version_extension'])
if override_dockerhub_repo is not None:
    cmd_call = cmd_call.replace('docker run nrel', 'docker run {}'.format(override_dockerhub_repo))
if verbose:
    print 'openstudio-rserve R version command is: {}'.format(cmd_call)
stdout_arr = run_cmd(cmd_call, 'R version retrieval').split('\n')[2].split('.')
r_version = stdout_arr[0][-1] + '.' + stdout_arr[1] + '.' + stdout_arr[2][0]
if verbose:
    print 'R version retrieved is {}'.format(r_version)

# Finally, we build the new hash to append to the amis.json array
ami_entry = {
    "name": defaults['version'] + defaults['ami_version_extension'],
    "notes": notes,
    "standards": {
        "ref": standards_version,
        "repo": "nrel/openstudio-standards"
    },
    "workflow": {
        "ref": workflow_version,
        "repo": "nrel/openstudio-workflow-gem"
    },
    "energyplus": eplus_version,
    "radiance": radiance_version,
    "analysis": {
        "ref": analysis_version,
        "repo": "nrel/openstudio-analysis-gem"
    },
    "openstudio": {
        "version_number": os_version,
        "version_sha": os_sha,
        "url_base": "https://s3.amazonaws.com/openstudio-builds/NUMBER/OpenStudio-NUMBER.SHA-Linux.deb"
    },
    "server": {
        "ref": server_sha,
        "repo": "nrel/openstudio-server"
    },
    "R": r_version,
    "ami": ami_id
}

# We set the AMI as publically available, unless disable_public is true
if not disable_public:
    ec2 = boto3.resource('ec2')
    image = ec2.Image(ami_id)
    response = image.modify_attribute(LaunchPermission={'Add': [{'Group': 'all'}]})
    if response['ResponseMetadata']['HTTPStatusCode'] is not 200:
        raise RuntimeError('API request setting AMI {} permissions to public failed to return status code 200, instead '
                           'returning code {}'.format(ami_id, response['ResponseMetadata']['HTTPStatusCode']))
    if verbose:
        print 'API request to make {} public returned status code 200'.format(ami_id)

# If the ami entry is getting persisted to file, instead of to S3, then short-circuit here
if write_to_file:
    write_path = os.path.abspath(os.path.join(output_dir, 'amis_extension.json'))
    with open(write_path, 'w') as f:
        f.write(json.dumps(ami_entry, indent=4))
    if verbose:
        print 'Wrote AMI entry to {}. Exiting with exit code 0'.format(write_path)
    sys.exit(0)

# Now that we have the required artifacts, we boot up the AWS library and download the latest amis.json
s3 = boto3.resource('s3',region_name='us-east-1')
file_obj = s3.Object('openstudio-resources', 'server/api/v3/amis.json')
amis = json.loads(file_obj.get()['Body'].read().decode('utf-8'))
if verbose:
    print 'Retrieved amis.json file from S3'
amis['builds'].append(ami_entry)

# Last of all, we add and upload the amis.json file
response = file_obj.put(ACL='public-read', Body=json.dumps(amis, indent=4))
if response['ResponseMetadata']['HTTPStatusCode'] is not 200:
    raise RuntimeError('API request uploading the updated amis.json file failed to return status code 200, instead '
                       'returning code {}'.format(response['ResponseMetadata']['HTTPStatusCode']))
if verbose:
    print 'Submitted updated amis.json file to S3 API which returned status code 200. Exiting'
sys.exit(0)
