require 'pry'
# require 'FileUtils.rb' # somehow unnecessary

class JPackage
   include FileUtils
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
      cd prefix
      @files.each do |file|
         cp file, "." if not File.exist? File.basename file
      end
      @subpackages.each_value do |p|
         return false if not p.build_directory root + @name
      end
      true
   end
end

class ClassCollector
   include FileUtils
   attr_reader :files
   CLS_DECL_REGEX =
      /((public|protected|private|abstract|static|final|strictfp)\s+)*(class|interface)\s+[A-Z]\w*\s*(<[A-Z](\sextends [A-Z]\w*)?(, [A-Z](extends [A-Z]\w*)?)*>)?(\s+(extends|implements)\s+[A-Z]\w*(\s*,\s*[A-Z]\w*)*)?.*\s*{\s*$/ 
   PKG_DCL_REGEX = /\s*package\s+\w+(\.\w+)*;\s*$/
   EXTR_PKG = [/\s*package\s+|;\s*/,""]
   def initialize root
      @root = root
      @files = Hash.new
   end
   def collect
      cd @root
      files = Dir.entries @root
      files.each do |fname|
         pkg_info = parsePkg fname
         @files[fname] = pkg_info if pkg_info
      end
   end
   def parsePkg fname
      if File.extname(fname) == ".java"
         lines = IO.readlines fname
         i = 0
         while i < lines.size and not lines[i].match CLS_DECL_REGEX
            if lines[i].match PKG_DCL_REGEX
               pkg_name = lines[i].gsub *EXTR_PKG
            end
            i += 1
         end
         pkg_name || "" # if we found nothing -> default package
      end
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
   # puts p.build_directory File.absolute_path "."
   t = ClassCollector.new "."
   t.collect
   puts t.files
end
