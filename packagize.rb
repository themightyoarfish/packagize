require 'pry'

class Package
   include FileUtils
   attr_reader :name, :subpackages, :files
   def initialize name
      @name = name
      @subpackages = Hash.new
      @files = Array.new
   end
   def add_subpackage pack
      if not pack.is_a? Package
         raise TypeError
      end
      @subpackages[pack.name] = pack if pack.name.match /^[a-zA-Z\d]+$/
   end
   def add_file file
      @files.push file
      puts "#{file} added to package #{@name}"
   end
   def to_s
      @name
   end
   def build_directory root
      root = root + "/" if not root.match(/.*\/$/)
      # puts "root: #{root}, wd: #{FileUtils.getwd}"
      # binding.pry
      Dir.mkdir @name if not File.exist? @name
      cd @name
      @files.each do |file|
         puts "moving file: "+file+" to "+File.absolute_path(".")
         cp file, "." 
      end
      @subpackages.each_value do |p|
         success = p.build_directory @name
         return false if not success
         cd ".."
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
      collect_in_dir File.absolute_path @root
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
   private
   def collect_in_dir directory
      if File.directory? directory
         cd directory
         files = Dir.entries directory
         files.reject! {|d| d.match /^\.{1,2}$/}
         files.each do |fname|
            if File.file? fname # if no directory
               # puts "file: #{fname}"
               pkg_info = parsePkg fname
               @files[File.absolute_path fname] = pkg_info if pkg_info
            else  
               # puts "dir: #{fname}"
               dirs = Dir.entries fname
               dirs.reject! {|d| d.match /^\.{1,2}$/}
               # puts dirs
               dirs.each do |entry|
                  collect_in_dir entry
               end
            end
         end
      end
   end
end

if __FILE__ == $0
   c = ClassCollector.new "."
   c.collect
   pkg_root = Package.new "src"
   c.files.each do |k,v|
      parent = pkg_root
      while not v.empty?
         subpkg_name = v.split(".").first
         subpkg = (parent.subpackages[subpkg_name] or Package.new subpkg_name)
         parent.add_subpackage subpkg unless parent.subpackages.has_key? subpkg.name
         parent = subpkg
         v.slice! subpkg.name
         if v.start_with? "."
            v = v[1,v.length]
         end
      end
      subpkg.add_file k
   end
   pkg_root.build_directory "."
end
