require "open-uri"

url = "https://raw.githubusercontent.com/github/gitignore/master/Rails.gitignore"
github_gitignore = URI.open(url).read

append_to_file ".gitignore", <<~LINES

  # The following was appended from #{url}
  #
  # START github/gitignore Rails.gitignore
  #
  ########################################
LINES

append_to_file ".gitignore", github_gitignore

append_to_file ".gitignore", <<~LINES
  ######################################
  #
  # END github/gitignore Rails.gitignore
LINES

