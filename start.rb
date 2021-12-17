$LOAD_PATH.unshift File.dirname(__FILE__)
require './lib/psd'



# psd = PSD.new('test.psd')
# psd.parse!

# pp psd.tree.to_hash
#  }

PSD.open('test.psd') do |psd|
    psd.tree.to_hash
    File.open('log.txt', 'w') { |file| file.write(psd.tree.children)}
end