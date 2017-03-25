#!/bin/sh

gem update fastlane
fastlane test
exit $?
