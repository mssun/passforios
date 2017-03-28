#!/bin/sh

gem update fastlane
fastlane test && fastlane beta
exit $?
