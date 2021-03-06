SWIFTLINT_VERSION="0.43.*"

if [[  "${CI}" == "true" ]]; then
  echo "Running in a Continuous Integration environment. Linting is skipped."
  exit 0
fi

if [[ "${CONFIGURATION}" == "Release" ]]; then
  echo "Running during a release build. Linting is skipped."
  exit 0
fi

if which swiftlint > /dev/null; then
  if [[ "$(swiftlint version)" == $SWIFTLINT_VERSION ]]; then
    swiftlint --strict
  else
    echo "Failure: SwiftLint $SWIFTLINT_VERSION is required. Install it or update the build script to use a newer version."
    exit 1
  fi
else
  echo "Failure: SwiftLint not installed. Get it via 'brew install swiftlint'."
  exit 2
fi

