lane :beta do
  ensure_git_status_clean
  increment_build_number(xcodeproj: "pass.xcodeproj")
  commit_version_bump(xcodeproj: "pass.xcodeproj")
  add_git_tag
  push_to_git_remote
  gym(scheme: "pass",
      workspace: "pass.xcworkspace",
      include_bitcode: true)
end
