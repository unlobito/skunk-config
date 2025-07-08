FROM ruby:3.4.4-bullseye

RUN apt update && apt install -y ghostscript && rm -rf /var/lib/apt/lists/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY public ./public/
COPY views ./views/
COPY app.rb config.ru xbi.rb ./

ENTRYPOINT exec bundle exec thin -R config.ru start -p $PORT -e $RACK_ENV
