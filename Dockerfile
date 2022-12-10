FROM ruby:2.7.7

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY public ./public/
COPY views ./views/
COPY app.rb config.ru xbi.rb ./

ENTRYPOINT exec bundle exec thin -R config.ru start -p $PORT -e $RACK_ENV
