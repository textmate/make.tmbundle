#!/usr/bin/env ruby

require ENV["TM_SUPPORT_PATH"] + "/lib/tm/executor"
require ENV["TM_SUPPORT_PATH"] + "/lib/tm/save_current_document"
require ENV["TM_SUPPORT_PATH"] + "/lib/escape"

TM_MAKE = e_sh(ENV['TM_MAKE'] || 'make')

TextMate::Executor.make_project_master_current_document

# Find and verify our makefile
ENV["TM_MAKE_FILE"] = File.expand_path('Makefile', ENV["TM_PROJECT_DIRECTORY"] || ENV["TM_DIRECTORY"]) unless File.file?(ENV["TM_MAKE_FILE"].to_s)

# Go next to the makefile
Dir.chdir(File.dirname(ENV["TM_MAKE_FILE"]))
TM_MAKE_FILE = File.basename(ENV["TM_MAKE_FILE"])

TM_MAKE_FLAGS = ["-w"]
TM_MAKE_FLAGS << "-f" + TM_MAKE_FILE
TM_MAKE_FLAGS << ENV["TM_MAKE_FLAGS"] unless ENV["TM_MAKE_FLAGS"].nil?

def perform_make(target = nil)
  dirs = [ENV['TM_PROJECT_DIRECTORY']]
  flags = TM_MAKE_FLAGS
  flags << target unless target.nil?
  TextMate::Executor.run(TM_MAKE, flags, :verb => "Making", :noun => (target || "default"), :use_hashbang => false) do |line, type|
    if line =~ /^g?make.*?: Entering directory `(.*?)'$/ and not $1.nil? and File.directory?($1)
      dirs.unshift($1)
      ""
    elsif line =~ /^g?make.*?: Leaving directory `(.*?)'$/ and not $1.nil? and File.directory?($1)
      dirs.delete($1)
      ""
    elsif line =~ /^\s*((.*?)\((\d+),(\d+)\):)(\s*(?:warning|error)\s+.*)$/ and not $1.nil?
      # smcs (C#)
      make_txmt_link(dirs, $2, $3, $4, $1, $5)
    elsif line =~ /^((.*?):(?:(\d+):)?(?:(\d+):)?)(.*?)$/ and not $1.nil?
      # GCC, et al
      make_txmt_link(dirs, $2, $3, $4, $1, $5)
    end
  end
end

def make_txmt_link(dirs, file, lineno, column, title, message)
  path = dirs.map{ |dir| File.expand_path(file, dir) }.find{ |path| File.file? path }
  unless path.nil?
    parms =  [    "url=file://#{e_url path}" ]
    parms << [   "line=#{lineno}"            ] unless lineno.nil?
    parms << [ "column=#{column}"            ] unless column.nil?
    info = file.gsub('&', '&amp;').gsub('<', '&lt;').gsub('"', '&quot;')
    "<a href=\"txmt://open?#{parms.join '&'}\" title=\"#{info}\">#{title}</a>#{htmlize message}<br>\n"
  end
end
