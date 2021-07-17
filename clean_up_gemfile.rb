require "pathname"
gemfile = Pathname.new("Gemfile")

[
  [/'([^']+)'/, '"\1"'], # use double-quotes
  [/^ruby[^,]*[^\d\.]((\d)(\.\d+)+)[^,\n]*/, 'ruby "~> \1"'], # loosen ruby version restriction
  [/(gem "rails".*)/, "\\1\n"], # place rails gem on its own line
  [/(gem \S+)(, ?"[^"]*\d[^"]*")+/, '\1'], # remove gem version restrictions
  [/, platforms: \[[^\]]+\]/, ''], # remove platform restrictions
  [/# Windows.*\ngem "tzinfo-data"/, ''], # remove concern for Windows
  [/^[[:blank:]]*#.*\n/, ''], # delete comments
  [/^\n{2,}/, "\n"], # collapse excess newlines
].each do |pattern, substitution|
  gsub_file gemfile, pattern, substitution
end

gem_groups = gemfile.read.scan(/(([[:blank:]]*gem .*\n)+)/)

gem_groups.each do |group, *_| # sort gem groups
  sorted = group.lines(chomp: true).sort.join("\n") + "\n"

  gsub_file gemfile, group, sorted
end
  
gsub_file gemfile, /^\n+\z/, '' # remove trailing newlines
