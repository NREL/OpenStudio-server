<!--
When opening a new issue, please first make sure that there are no duplicate
tickets open. To check for this, please search the issue list for this repo.
In the case that there is a duplicate issue, please close the issue you have
opened and add any clarifying information to the issue with precedence.

Should you believe that the issue you're opening classifies as a bug, please
fill out the BUG REPORT INFORMATION form listed below. Should you not provide
this information within two weeks the issue will be closed until the
information is provided, at which point the issue will be re-opened and
addressed.

For more information about issues, please refer to
https://github.com/NREL/OpenStudio/wiki/Issue-Prioritization


---------------------------------------------------
SUPPORT GUIDELINES
---------------------------------------------------

This issue list is for both feature requests and bug reports.
The contribution policy can be found at
https://github.com/NREL/openstudio-server/blob/develop/CONTRIBUTING.md
General support can be found at Unmet Hours -
https://unmethours.com/questions/

---------------------------------------------------
BUG REPORT INFORMATION
---------------------------------------------------
Please execute the commands below to provide key information regarding the
bug you are reporting. Note that the commands to execute are dependent on the
type of issue being submitted, i.e. meta-cli vs local server vs local docker
deployment vs aws docker deployment.
You do NOT have to include this information if this is a FEATURE REQUEST
-->
### General Issue / Feature Information

**Description**

<!--
Briefly describe the problem you are having in a few paragraphs.
-->

**Reproduction steps:**
1.
2.
3.

**Actual outcome:**


**Expected outcome:**


**Other information (i.e. issue is intermittent):**

<!--
META-CLI / SERVER FAILS TO LAUNCH FROM PAT SECTION
Please provide this information if the issue relates to the meta-cli,
i.e. if a local or remote server fails to start, stop, or submit an
analysis as expected. This includes issues with PAT starting or stopping
local or remote servers, or submitting analyses to the servers. Otherwise,
please delete this section from your issue submission.
-->
### Meta-CLI / PAT Server Fails to Launch Details

**Client operating system version:**

(i.e. OSX 10.10.2 or Windows 7 SP1)


**OpenStudio Meta-CLI providence**

(i.e. PAT 2.4.1 or clone of openstudio-server SHA abcd1234)

**Command executed:**

```
(paste the executed command run here - if using PAT this can be retrieved
from the developer tools console window. You may need to enable debug
messages and reproduce the error again.)
```

**Result of command:**

```
(paste the command results here - again if using PAT this can be
retrieved from the developer console window. Please ensure no
sensitive information - e.g. sensitive environment variables
- is included in the log.)
```

<!--
ERROR ON LOCAL SERVER
Please provide this information if the issue relates to an instance
of the openstudio-server locally deployed via the meta-cli,
i.e. if using a local server launched on start-up by PAT
-->

### Error on Local Server Details

**Client operating system version:**

(i.e. OSX 10.10.2 or Windows 7 SP1)


**OpenStudio Server providence**

(i.e. PAT 2.4.1 or clone of openstudio-server SHA abcd1234)

**Local log files**


(While the server is still running in the erred state - i.e. PAT is still
open - please go to the project directory, and zip the log directory. Then
attach the zip file to the issue submission, and replace this text with
'Attached'.)

<!--
ERROR ON REMOTE SERVER
Please provide this information if the issue relates to an instance
of the openstudio-server running on AWS, or using docker on a user
controlled workstation
-->

### Error on Remote Server Details

**AMI version being used**

(i.e. 2.4.1 - this information can be found under the Server Information
header on the Admin page of the OpenStudio Server instance.)

**Server management log file**

(Navigate to the server management console, click on the analysis that 
erred, and then click on the 'View: Log' button. Copy the entire page
using control/command a into a text editor, and save the file as a .txt
file. Then, please attach the file to the issue submission.)

<!--
ERROR DEPLOYING WITH DOCKER ON A USER CONTROLLED WORKSTATION
Please provide this information if the issue relates to creating a
docker based deployment of the OpenStudio Server on a user controlled
workstation, i.e. if `docker stack deploy` fails to deploy the server
-->

### Docker Provisioning Error Details

**Deployment machine operating system version**

(i.e. Ubuntu 16.04 or CentOS 7.3)

**Docker version**

```
(paste the results of the 'docker version' command on the deployment
machine)
```

**Openstudio Server version / dockerhub tag used**

(i.e. SHA abcd1234 or nrel/openstudio-server:latest)

**docker-compose.yml file used**

(Please attach the docker-compose.yml file being used, if applicable)

<!--
Thanks for submitting your issue!!! We'll get back to you soon!
-->
