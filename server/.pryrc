require 'awesome_print'
Pry.config.print = proc { |output, value| output.puts "=> #{ap value}" }

Pry.config.editor = "subl"
