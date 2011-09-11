
require 'database'
require 'utilities'

role :local, "local"
set :roles, [:local]

# local deployment namespace
[:local].each do |env|
    namespace env do

        ##########
        #DataBase#
        ##########

        desc "baseline #{env} database"
        task "db-baseline", :roles => env do
            baseline_db_scripts env
        end

        desc "apply #{env} database patches"
        task "db-patch", :roles => env do
            apply_db_patches env
        end

        desc "apply #{env} database rollbacks"
        task "db-rollback", :roles => env do
            apply_db_rollbacks env
        end

        # hidden task called by mvn install only
        task "db-patch-init", :roles => env do
            init_db_patch_dir
        end
    end
end
