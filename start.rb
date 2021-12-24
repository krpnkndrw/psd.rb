$LOAD_PATH.unshift File.dirname(__FILE__)
require './lib/psd'
require 'pp'



psd = PSD.new('test.psd')
psd.parse!

psd.tree.children[2].to_hash
# pp psd.tree.children[2].to_hash

# PSD.open('test.psd') do |psd|
#     psd.parse!
#     pp psd.tree.children

#     # File.open('log.txt', 'w') { |file| file.write(psd.tree.children)}
# end