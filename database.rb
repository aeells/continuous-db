
def baseline_db_scripts(env)
    db = load_db_config env
    db_password = prompt_db_password_if_empty "#{db['password']}", "#{db['host']}", "#{db['database']}"

    if "#{env}" == "local"
        run_local "sh src/main/resources/scripts/baseline/baseline.sh #{db['user']} #{db_password} #{db['host']} #{db['database']}"
    else
        p "to be implemented for remote..."
    end
end

def apply_db_patches(env)
    db = load_db_config env
    db_password = prompt_db_password_if_empty "#{db['password']}", "#{db['host']}", "#{db['database']}"

    if "#{env}" == "local"
        run_local "sh src/main/resources/scripts/patches/patch.sh #{db['user']} #{db_password} #{db['host']} #{db['database']}"
    else
        p "to be implemented for remote..."
    end
end

def apply_db_rollbacks(env)
    db = load_db_config env
    db_password = prompt_db_password_if_empty "#{db['password']}", "#{db['host']}", "#{db['database']}"

    if "#{env}" == "local"
        run_local "sh src/main/resources/scripts/patches/rollback.sh #{db['user']} #{db_password} #{db['host']} #{db['database']}"
    else
        p "to be implemented for remote..."
    end
end

def load_db_config(env)
    require 'yaml'
    database = YAML::load_file('database.yaml')[env.to_s()]
    database
end

def prompt_db_password_if_empty(existing_password, db_host, db_database)
    if existing_password.empty?
        puts "\nPlease enter password to access '#{db_database}' database on '#{db_host}':"
        password = $stdin.gets.chomp
    else
        password = existing_password
    end
    password
end

def init_db_patch_dir
    version_number = retrieve_pom_release_version "pom.xml"

    repo_already_exists = File.directory? "src/main/resources/scripts/patches/#{version_number}"

    if !repo_already_exists
        run_local "mkdir -p src/main/resources/scripts/patches/#{version_number}/patch"
        run_local "mkdir -p src/main/resources/scripts/patches/#{version_number}/rollback"
        run_local "touch src/main/resources/scripts/patches/#{version_number}/install.txt"
    end
end
