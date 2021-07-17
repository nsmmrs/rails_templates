scheme = ask "Which naming scheme would you like?",
  limited_to: %w[ docker container ],
  default: "docker" 

container_file = scheme.capitalize + "file"
compose_file = scheme + "-compose.yml"

version = IO.read("Gemfile.lock")
            .match(/RUBY VERSION\s+ruby (?<major_minor>\d\.\d)/)
            .[](:major_minor)
        
create_file container_file, <<~LINES
  FROM ruby:#{version}-slim AS dev

  RUN apt-get update -qq \\
   && apt-get install -y --no-install-recommends \\
      nodejs \\
      postgresql-client \\
   && apt-get clean autoclean \\
   && apt-get autoremove -y \\
   && npm install --global yarn

  ARG BUNDLE_JOBS
  ARG BUNDLE_RETRY
  ARG BUNDLE_WITHOUT

  WORKDIR /#{app_name}
  COPY Gemfile* .
  RUN bundle install
  COPY . .

  FROM dev AS prod

  RUN bundle exec rails assets:precompile
LINES

create_file "entrypoint.sh", <<~LINES
  #!/usr/bin/env bash
  set -e

  # Remove a potentially pre-existing server.pid for Rails.
  rm -f tmp/pids/server.pid

  # Run CMD
  exec "$@"
LINES

compose_file_body = <<~LINES
  version: "3.8"
  services:
    db:
      image: postgres
      environment:
        POSTGRES_PASSWORD: postgres
      volumes:
        - postgresql_data:/var/lib/postgresql/data
    web:
      command: ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
      entrypoint: /#{app_name}/entrypoint.sh
      build: .
      image: #{app_name}
      volumes:
        - .:/#{app_name}:z
        - gem_home:/usr/local/bundle
      ports:
        - "30#{rand(1..9)}#{rand(1..9)}:3000"
      depends_on:
        - db
LINES

backend = ask "Which ActiveJob backend are you using?",
  limited_to: %w[ good_job delayed_job other none ],
  default: "good_job"

worker_cmd = case backend
when "delayed_job"
  %w[ bundle exec rake jobs:work ]
when "good_job"
  %w[ bundle exec good_job start ]
when "other"
  ask(<<~QUESTION).split
    Enter the command used to start the worker:
  QUESTION
end

compose_file_body += <<~LINES.indent(2) if worker_cmd
  worker:
    image: #{app_name}
    command: #{worker_cmd.inspect}
    volumes:
      - .:/#{app_name}:z
      - gem_home:/usr/local/bundle
    depends_on:
      - db
LINES

compose_file_body += <<~LINES
  volumes:
    gem_home:
    postgresql_data:
LINES

create_file compose_file, compose_file_body

remove_file "config/database.yml"
create_file "config/database.yml", <<~LINES
  default: &default
    adapter: postgresql
    encoding: unicode
    host: db
    username: postgres
    password: postgres
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  development:
    <<: *default
    database: #{app_name}_development
  test:
    <<: *default
    database: #{app_name}_test
  production:
    <<: *default
    database: #{app_name}_production
LINES

if yes?("Add heroku.yml?")
  heroku_yml = <<~LINES
    build:
      docker:
        web: #{container_file}
      config:
        BUNDLE_JOBS: 10
        BUNDLE_RETRY: 3
        BUNDLE_WITHOUT: development:test
    run:
      web: bundle exec rails server
  LINES

  heroku_yml += <<~LINES.indent(2) if worker_cmd
    worker:
      command:
        - #{worker_cmd.join(" ")}
      image: web
  LINES

  create_file "heroku.yml", heroku_yml
end
