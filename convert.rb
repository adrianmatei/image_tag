#!/usr/bin/env ruby
require "nokogiri"

# opens every file in the given dir tree and converts any html img tags to rails image_tag calls
#
# example usage:
# ruby convert.rb ~/my_rails_app/app/views
#

raise "no directory tree given" if ARGV.first.nil?

path = "#{ARGV.first}/**/*"

@count = {
  :files_open => 0,
  :files_revised => 0,
  :tags => 0
}

class RailsImageTag

  Params = [
    { :name => :alt },
    { :name => :height, :type => :int },
    { :name => :width, :type => :int },
    { :name => :class}
  ]

  def initialize(img)
    @img = img
  end

  # construct and return the erb containing the new image_tag call
  def to_erb
    url = @img['src']
    url.sub!("/images/", "")

    options_str = process_options
    "<%= image_tag '#{url}'#{options_str} %>"
  end

  # convert the img tag params to image_tag options
  # the params to process are defined in the Params constant hash
  def process_options
    img_string = @img.to_s
    options_erb = {}

    Params.each do |opt|
      name = opt[:name]
      value = @img[name]

      unless value.nil?
        options_erb[name] = "#{name}: '#{value}'"
      end
    end

    # extract data attributes
    while img_string.include? 'data-'
      removed_left_content = img_string.slice(img_string.index("data-")..-1)
      data_attribute = (removed_left_content.slice(0..(removed_left_content.index('=')))).tr('=', '')
      data_value = @img[data_attribute]

      options_erb[data_attribute] = "'#{data_attribute}': '#{data_value}'"

      img_string.gsub!(data_attribute, "")
    end

    options_erb.empty? ? "" : ", " + options_erb.values.join(", ")
  end

end

class HtmlDoc

  def initialize(filename)
    @name = filename
    file = File.open(@name)
    @doc = Nokogiri::HTML(file)
    @content = File.open(@name) { |f| f.read }
  end

  # overwrite the file with new contents
  def write_file(log)
    log[:files_revised] += 1
    File.open(@name, "w") {|f| f.write(@content) }
  end

  # convert a single file and record stats to <em>log</em>
  def convert_img_tags!(log)
    log[:files_open] += 1
    file_marked = false
    @doc.xpath("//img").each do |img|
      file_marked = true
      log[:tags] += 1

      original = img.to_html.gsub("\">", "\" />").gsub("\" >", "\" />").delete("\\")
      original2 = img.to_html.gsub("\">", "\"/>").gsub("\" >", "\" />").delete("\\")
      image_tag = RailsImageTag.new(img).to_erb

      @content.gsub!(original, image_tag)
      @content.gsub!(original2, image_tag)

      puts "Generated image_tag:"
      puts image_tag
    end

    write_file(log) if file_marked
  end

end

Dir.glob(path).each { |filename| HtmlDoc.new(filename).convert_img_tags!(@count) if File.file?(filename) }

p "***********************************"
p "#{@count[:files_open]} files opened"
p "#{@count[:files_revised]} files revised"
p "#{@count[:tags]} tags replaced"
