#!/bin/sh

gem update fastlane
if [ "$TRAVIS_PULL_REQUEST" == "true" ]; then
    fastlane test; 
else
    fastlane travis;
fi
exit $?
