def pipeline
  require 'rake-pipeline'
  Rake::Pipeline::Project.new(EmberDev.config.assetfile)
end

def ensure_defeatureify
  return unless File.exists?('features.json')

  command_path = 'node_modules/.bin/defeatureify'

  unless File.exists?(command_path)
    abort "You have a `features.json` file, but defeatureify is not installed. You can install it with:\n\tnpm install defeatureify"
  end

  required_version  = '~> 0.2.0'
  installed_version = `#{command_path} --version`.chomp

  unless Gem::Requirement.new(required_version) =~ Gem::Version.new(installed_version)
    abort "`defeatureify` (#{required_version}) is required, but we found (#{installed_version}) in '#{command_path}'. You can install it with:\n\tnpm install defeatureify"
  end
end

def ensure_es6_module_transpiler
  return unless File.exists?('packages_es6')

  command_path = 'node_modules/.bin/compile-modules'

  unless File.exists?(command_path)
    abort "You must have es6-module-transpiler installed to build Ember. You can install it with:\n\tnpm install"
  end
end

config = EmberDev.config

namespace :ember do
  desc "Tranpile ES6 Modules"
  task :transpile do
    ensure_es6_module_transpiler

    sh './bin/transpile-packages.js' if File.exists?('packages_es6')
  end

  desc "Build ember.js"
  task :dist => :transpile do
    ensure_defeatureify

    puts "Building #{config.name}..."
    pipeline.invoke
    puts "Done"
  end

  desc "Clean build artifacts from previous builds"
  task :clean do
    puts "Cleaning build..."
    rm_rf "dist" # Make sure even things RakeP doesn't know about are cleaned
    rm_rf "tmp"
    puts "Done"
  end

  desc "Build Ember.js from a given fork & branch"
  task :build, :username, :branch do |t, args|
    require "grit"

    if args.to_hash.keys.length != 2
      puts "Usage: rake build[wycats,some-cool-feature]"
      exit 1
    end

    username, branch = args[:username], args[:branch]

    remote_path = "https://github.com/#{username}/ember.js.git"

    repo = Grit::Repo.new(File.dirname(File.expand_path(__FILE__)))

    unless repo.remotes.map(&:name).grep(/#{username}/).length == 0
      repo.remote_add(username, remote_path)
    end

    repo.remote_fetch username

    sh("git checkout -B testing-#{username}-#{branch} master")
    sh("git merge #{username}/#{branch}")

    puts "Resolve possible merge conflicts and run `rake dist`"
  end
end
