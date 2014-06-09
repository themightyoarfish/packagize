#!/usr/bin/env ruby
require 'pry'

if RUBY_VERSION.to_f < 1.9
   puts "Your interpreter version is #{RUBY_VERSION}. This tool requires ruby
   1.9.* or higher to run."
   exit
end

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
      if pack.name =~ /^[a-zA-Z\d]+$/
         @subpackages[pack.name] = pack 
      else puts "Invalid pacakge name #{pack.name}. skipping."
      end
   end
   def add_file file
      @files.push file
      puts "#{File.basename file} added to package #{@name}"
   end
   def to_s
      @name
   end
   def build_directory root
      success = true
      root += "/" if not root.end_with? "/" # add backslash for later concatenation
      Dir.mkdir(root + @name) if not File.exist? root + @name
      @files.each do |file|
         puts "moving file #{File.basename file} to #{File.absolute_path '.'}"
         begin
            cp file, root + @name 
         rescue ArgumentError => e # raised if files are identical
               puts "Error. Can't copy #{File.basename file}. Source and destination are identical."
         end
      end
      @subpackages.each_value do |p|
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

   ## constants

   # this tries to match the more common java class headers. Doesn't match every
   # possible way, I supposed. Especially nested generics can't be checked with
   # a regex
   CLS_DECL_REGEX =
      /((public|protected|private|abstract|static|final|strictfp)\s+)*(class|interface)\s+[A-Z]\w*\s*(<[A-Z](\sextends [A-Z]\w*)?(, [A-Z](extends [A-Z]\w*)?)*>)?(\s+(extends|implements)\s+[A-Z]\w*(\s*,\s*[A-Z]\w*)*)?.*\s*\{\s*$/ # note that { must be escaped in 1.8
   # this tries to match a package declaration
   PKG_DCL_REGEX = /\s*package\s+\w+(\.\w+)*;\s*$/
   # for extracting the actual package path without 'package' and ';'
   EXTR_PKG = [/\s*package\s+|;\s*/,""]

   def initialize root=".", ext=".java"
      @root = File.absolute_path root
      @files = Hash.new # files found
      @extension = ext
   end
   def collect
      collect_in_dir  @root
   end
   def parsePkg fname
      if File.extname(fname) == @extension
         lines = IO.readlines fname
         lines.each do |l|
            break if l =~ CLS_DECL_REGEX
            if l =~ PKG_DCL_REGEX
               pkg_name = l.gsub *EXTR_PKG
               return pkg_name
            end
         end
         puts "Warning: #{File.basename fname} has no or no valid package
            declaration. Adding to default pacakge."
         "" # if we found nothing -> default package
      end
   end

   private
   def collect_in_dir directory
      directory += "/" if not directory.end_with? "/"
      if File.directory? directory
         files = Dir.entries directory
         files.reject! {|d| d.match /^\.{1,2}$/} # ignore parent and self links
         files.map! { |f| directory + f }
         files.each do |fname|
            if File.file? fname # if no directory
               pkg_info = parsePkg fname
               @files[fname] = pkg_info if pkg_info
            else  
               collect_in_dir fname
            end
         end
      end
   end
end

if __FILE__ == $0
   c = ClassCollector.new ARGV[0]
   c.collect
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
   success = pkg_root.build_directory File.absolute_path ARGV[1]
   puts success ? "Done." : "There were errors."
end
