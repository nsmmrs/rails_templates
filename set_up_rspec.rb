gem_group :development, :test do
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails"
end

gem_group :test do
  gem "fuubar"
  gem "webmock"
end

run "bundle install"
generate "rspec:install"

append_to_file ".rspec", <<~LINES
  --format Fuubar
  --color
LINES

prepend_to_file "spec/spec_helper", <<~LINES
  require 'webmock/rspec'

LINES

