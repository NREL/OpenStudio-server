Instruction for building 64 bit Windows 7, 64 bit Windows 8, 64 bit Windows 10, and Yosemite

Making OpenStudio Server Zip

Clone OpenStudio-server (git@github.com:NREL/OpenStudio-server.git)

Checkout branch “dockerize-pat”

cd into bin

Run “c:/path/to/ruby.exe  openstudio_meta install_gems --debug –verbose”

Verify run log contains no errors

Zip contents into compressed file (Employ OpenStudio naming convention)

Upload zip file to S3 bucket “openstudio-resources/pat-dependencies”
