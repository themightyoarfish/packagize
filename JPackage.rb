require 'pry'
# require 'FileUtils.rb' # somehow unnecessary

class JPackage
   attr_reader :name, :subpackages, :files
   def initialize name
      @name = name
      @subpackages = Hash.new
      @files = Array.new
   end
   def add_subpackage pack
      @subpackages[pack.name] = pack if pack.name.match /^[a-z\d]+$/
   end
   def add_file file
      @files.push file
   end
   def build_directory root
      root = root + "/" if not root.match(/.*\/$/)
      prefix = "#{root}#{@name.downcase}"
      Dir.mkdir prefix if not File.exist? prefix
      FileUtils.cd prefix
      @files.each do |file|
         FileUtils.cp file, "." if not File.exist? File.basename file
      end
      @subpackages.each_value do |p|
         return false if not p.build_directory root + @name
      end
      true
   end
end

if __FILE__ == $0
   p = JPackage.new "pack1"
   p.add_file File.absolute_path("tmp/1.txt")
   p2 = JPackage.new "pack2"
   p2.add_file File.absolute_path("tmp/2.txt")
   p2.add_file File.absolute_path("tmp/3.txt")
   p.add_subpackage p2
   puts File.absolute_path "."
   puts p.build_directory File.absolute_path "."
end
