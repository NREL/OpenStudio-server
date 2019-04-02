# Release Instructions

1. Update version in server/app/lib/openstudio_server/version.rb
1. Run the `lib/change_log.rb` script and add the changes to the CHANGELOG.md file for the range of time between last release and this release.

    ```
    ruby lib/change_log.rb --token $GITHUB_API_TOKEN --start-date 2018-02-26 --end-date 2018-05-30
    ```

1. Paste the results into the CHANGELOG.md and clean up the list to only the pertinent changes.
1. Push changes to new release branch. 
1. Once branch passes, then create a new PR to develop, then one from develop to master.
1. Draft new Release from Github (https://github.com/NREL/openstudio-server/releases).
1. Include list of changes since previous release (i.e. the content in the CHANGELOG.md)
1. Verify that the Docker versions are built and pushed to Docker hub (https://hub.docker.com/r/nrel/openstudio-server/tags/).
1. Update OpenStudio version references in OSS CI config once the new version is released.
