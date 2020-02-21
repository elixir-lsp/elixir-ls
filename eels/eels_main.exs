# Main entrypoint of language server script.
# This is distributed as an Elixir script because
# we don't want to deal with the complexities of maintaining
# parallel scripts for Unix and NT like environments. Going
# to Elixir helps a lot :)

### Step one: compile our application.

full_version = "eels-#{System.version}-otp#{System.otp-release}"
target_path = "cached-versions/#{full_version}"

if not File.dir?(target_path) do
  File.mkdir_p!(target_path)
end



### Step two: start our application
