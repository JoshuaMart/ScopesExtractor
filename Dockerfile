FROM --platform=linux/amd64 ruby:3.4.2

WORKDIR /app
COPY . .
COPY Gemfile Gemfile

RUN bundle install

CMD ruby bin/main.rb
