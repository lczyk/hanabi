#!/usr/bin/env ruby
require_relative 'hanabi'

src = File.read(ARGV[0])
h = Hanabi.new(src)
dots = h.instance_variable_get(:@dots)
dots.each_with_index do |d, i|
  u, dd, l, r = d[:ws]
  puts "#{i}: (#{d[:r]},#{d[:c]}) U=#{u} D=#{dd} L=#{l} R=#{r}"
end
