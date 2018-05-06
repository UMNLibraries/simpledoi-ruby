Dir[File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', '**', '*.rb'))].reject{|file| file == File.expand_path(__FILE__)}.each { |file| require_relative(file) }
