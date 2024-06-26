FROM --platform=linux/amd64 ruby:3.2.2

# Install gems
WORKDIR /app
COPY . .
COPY Gemfile Gemfile

RUN bundle install

CMD ruby bin/main.rb