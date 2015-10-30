Dir[File.expand_path("lib/**/*.rb")].each { |file| require_relative(file) }
