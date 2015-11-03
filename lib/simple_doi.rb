Dir[File.expand_path(File.join(File.dirname(__FILE__), '..','lib','**','*.rb'))].each { |file| require_relative(file) }
