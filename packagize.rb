#!/usr/bin/env ruby
# require "FileUtils.rb"
require "pry"

if RUBY_VERSION.to_f < 1.9
   puts "Your interpreter version is #{RUBY_VERSION}. This tool requires ruby
   1.9.* or higher to run."
   exit
end

module JTools
   ## constants

   # this tries to match the more common java class headers. Doesn't match every
   # possible way, I suppose. Especially nested generics can't be checked with
   # a regex
   CLS_DECL_REGEX = /.*(class|interface|enum).*/
   # CLS_DECL_REGEX =
      # /((public|protected|private|abstract|static|final|strictfp)\s+)*(class|interface)\s+[A-Z]\w*\s*(<[A-Z](\sextends [A-Z]\w*)?(, [A-Z](extends [A-Z]\w*)?)*>)?(\s+(extends|implements)\s+[A-Z]\w*(\s*,\s*[A-Z]\w*)*)?.*\s*\{\s*$/ # note that { must be escaped in 1.8
   # this tries to match a package declaration
   PKG_DCL_REGEX = /\s*package\s+\w+(\.\w+)*;\s*$/
   # for extracting the actual package path without 'package' and ';' by use of
   # String#gsub. Simply deletes the word 'package' and the trailing semicolon
   # as well as whitespace
   EXTR_PKG = /\s*package\s+|;\s*/
   # This tries to match allowed package names, which must not begin with an
   # uppercase letter or number
   PACKAGE_NAME = /^([a-z]|(_\d*))+$/

end

=begin
   This class is represents a (java) package; basically just a collection of files
   and subpackages. 
=end
class Package
   include FileUtils # for cp
   attr_reader :name, :subpackages, :files
   def initialize name
      @name = name
      @subpackages = Hash.new
      @files = Array.new
   end
   # add a Package object as a subpackage of this package
   def add_subpackage pack
      if not pack.is_a? Package
         raise TypeError
      end
      if pack.name =~ JTools::PACKAGE_NAME
         @subpackages[pack.name] = pack # map name to package object
      else puts "Invalid pacakge name #{pack.name}. skipping."
      end
   end
   # add a file (not a Package) to this package. The file's package declaration
   # should end with the name of this Package
   def add_file file
      if not File.file? file
         raise ArgumentError
      else
         @files.push file
         puts "#{File.basename file} added to package #{@name}"
      end
   end
   def to_s
      "#{@name} => Files: \n\t#{@files.join "\n\t"}\n Subpackages:
      \t#{@subpackages.keys.join "\n\t"}"
   end
   # build the physical package structure on the file system with all
   # subpackages and files correctly arranged
   def build_directory root
      success = true
      root += "/" if not root.end_with? "/" # add backslash for later concatenation
      Dir.mkdir(root + @name) if not File.exist? root + @name # make root dir if not already present
      @files.each do |file|
         puts "moving file #{File.basename file} to #{root + @name}"
         begin
            cp file, root + @name 
         rescue ArgumentError => e # raised if files are identical
            puts "Warning: Can't copy #{File.basename file}. Source and destination are identical."
         end
      end
      @subpackages.each_value do |p| # recursively build directory tree
         success = p.build_directory root + @name
      end
      if success
         return true
      else
         return false
      end
   end
end

class ClassCollector
   include FileUtils
   attr_reader :files
   def initialize root=".", ext=".java"
      @root = File.absolute_path root
      @files = Hash.new # files found
      @extension = ext
   end
   def collect recursive=true
      collect_in_dir  @root, recursive
   end
   def parsePkg fname
      if File.extname(fname) == @extension
         lines = IO.readlines fname
         lines.each do |l|
            break if l =~ JTools::CLS_DECL_REGEX # stop if we find the class header
            next if l.strip.start_with? "/*", "*", "//"
            if l =~ JTools::PKG_DCL_REGEX # if package declaration found
               pkg_name = l.gsub JTools::EXTR_PKG, "" # extract path
               return pkg_name
            end
         end
         puts "Warning: #{File.basename fname} has no or no valid package
            declaration. Adding to default package."
         "" # if we found nothing -> default package
      else
         puts "Error. #{fname} is no #{@extension} file."
      end
   end

   private
   # collect all files with the given extension in a directory
   def collect_in_dir directory, recursive=true
      if not File.readable? directory
         puts "#{directory} not readable. Skipping."
      else
         directory += "/" if not directory.end_with? "/"
         if File.directory? directory
            files = Dir.entries directory
            files.reject! {|d| d.match /^\.{1,2}$/} # ignore parent and self links
            files.map! { |f| directory + f }
            files.each do |fname|
               if File.directory? fname and recursive
                  collect_in_dir fname
               elsif not File.readable? fname
                  puts "#{fname} not readable.Skipping."
               elsif File.file? fname and File.extname(fname) == @extension # if no directory
                  pkg_info = parsePkg fname
                  @files[fname] = pkg_info if pkg_info
               end
            end
         end
      end
   end
end

if __FILE__ == $0
   recursive = false
   recursive = true if ARGV.index "-r"
   search_dir = "."
   search_flag_pos = ARGV.index "-s"
   if search_flag_pos
      search_dir = ARGV[search_flag_pos + 1]
      puts "Error. Path must follow -s flag." if not search_dir
   end
   dest_dir = "."
   dest_flag_pos = ARGV.index "-d"
   if dest_flag_pos
      dest_dir = ARGV[dest_flag_pos + 1]
      puts "Error. Path must follow -d flag." if not dest_dir
   end
   c = ClassCollector.new search_dir
   c.collect recursive
   pkg_root = Package.new "src"
   c.files.each do |k,v|
      parent = pkg_root
      if v.empty?
         parent.add_file k
      else
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
   end
   binding.pry
   success = pkg_root.build_directory File.absolute_path dest_dir
   puts success ? "Done." : "There were errors."
end
