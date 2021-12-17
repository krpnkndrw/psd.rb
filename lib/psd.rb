$LOAD_PATH.unshift File.dirname(__FILE__)
require 'forwardable'
require 'psd/enginedata'
require 'chunky_png'
require 'xmp'

require 'psd/blend_mode'
require 'psd/channel_image'
require 'psd/color'
require 'psd/descriptor'
require 'psd/file'
require 'psd/header'
require 'psd/helpers'
require 'psd/image'
require 'psd/layer'
require 'psd/layer_info'
require 'psd/layer_mask'
require 'psd/lazy_execute'
require 'psd/logger'
require 'psd/mask'
require 'psd/node'
require 'psd/path_record'
require 'psd/renderer'
require 'psd/resources'
require 'psd/slices'
require 'psd/util'
require 'psd/version'

# A general purpose parser for Photoshop files. PSDs are broken up in to 4 logical sections:
# the header, resources, the layer mask (including layers), and the preview image. We parse
# each of these sections in order.
class PSD
  include Logger
  include Helpers
  include Slices

  attr_reader :file, :opts
  alias :options :opts

  # Opens the named file, parses it, and makes it available for reading. Then, closes it after you're finished.
  # @param filename [String]  the name of the file to open
  # @return [PSD] the {PSD} object if no block was given, otherwise the value of the block
  def self.open(filename, opts={}, &block)
    raise "Must supply a block. Otherwise, use PSD.new." unless block_given?

    psd = PSD.new(filename, opts)
    psd.parse!

    if 0 == block.arity
      psd.instance_eval(&block)
    else
      yield psd
    end
  ensure
    psd.close if psd
  end

  # Create and store a reference to our PSD file
  def initialize(file, opts={})
    @file = PSD::File.new(file, 'rb')
    @file.seek 0 # If the file was previously used and not closed

    @opts = opts
    @header = nil
    @resources = nil
    @layer_mask = nil
    @parsed = false
  end

  # Close the PSD file
  def close
    file.close unless file.closed?
  end

  # There is a specific order that must be followed when parsing
  # the PSD. Sections can be skipped if needed. This method will
  # parse all sections of the PSD.
  def parse!
    header
    resources
    layer_mask
    image
    
    @parsed = true

    return true
  end

  # Has our PSD been parsed yet?
  def parsed?
    @parsed
  end

  # Get the Header, parsing it if needed.
  def header
    return @header if @header

    @header = Header.new(@file)
    @header.parse!

    PSD.logger.debug @header.inspect
  end

  # Get the Resources section, parsing if needed.
  def resources
    return @resources unless @resources.nil?

    ensure_header

    @resources = Resources.new(@file)
    @resources.parse

    return @resources
  end

  # Get the LayerMask section. Ensures the header and resources
  # have been parsed first since they are required.
  def layer_mask
    ensure_header
    ensure_resources

    @layer_mask ||= LayerMask.new(@file, @header, @opts).parse
  end

  # Get the full size flattened preview Image.
  def image
    ensure_header
    ensure_resources
    ensure_layer_mask

    @image ||= (
      # The image is the last section in the file, so we don't have to
      # bother with skipping over the bytes to read more data.
      image = Image.new(@file, @header)
      LazyExecute.new(image, @file)
        .later(:parse)
        .ignore(:width, :height)
    )
  end

  private

  def ensure_header
    header # Header is always required
  end

  def ensure_resources
    return unless @resources.nil?
    
    @resources = Resources.new(@file)
    @resources.skip
  end

  def ensure_layer_mask
    return unless @layer_mask.nil?

    @layer_mask = LayerMask.new(@file, @header, @opts)
    @layer_mask.skip
  end
end
