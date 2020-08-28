SWIFTLINT_VERSION="0.40.*"

if [[ -f "${SRCROOT}/.ci-env" ]]; then
  echo "Running in a Continuous Integration environment. Linting is skipped."
  return
fi

if [[ "${CONFIGURATION}" != "Debug" ]]; then
  echo "Running during a release build. Linting is skipped."
  return
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

