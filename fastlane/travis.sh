#!/bin/sh

gem update fastlane
gem install xcodeproj
if [ "$TRAVIS_PULL_REQUEST" == "true" ]; then
    fastlane test; 
else
    fastlane travis;
fi
exit $?
