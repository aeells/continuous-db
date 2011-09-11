
def retrieve_pom_release_version(pom_path)
    require 'rexml/document'
    pom_exists = File.exists? "#{pom_path}"
    if pom_exists
        pom = REXML::Document.new File.new("#{pom_path}")
        pom_version = REXML::XPath.first(pom, "/project/version/text()")
        pom_version.to_s().gsub("-SNAPSHOT", "")
    else
        ""
    end
end

def run_local(command)
    unless system command
        puts "Failed to execute - #{command}"
        puts "Error             - #{$?}"
        exit
    end
end
