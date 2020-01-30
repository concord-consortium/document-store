FROM ruby:2.1.2
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9D6D8F6BC857C906
RUN apt-get update -qq && apt-get install -y --force-yes build-essential postgresql-client libpq-dev nodejs

ENV APP_HOME /myapp
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

# use a mounted volume so the gems don't need to be rebundled each time
ENV BUNDLE_GEMFILE $APP_HOME/Gemfile
ENV BUNDLE_JOBS 2
ENV BUNDLE_PATH /bundle
ENV RAILS_ENV development

EXPOSE 3000
