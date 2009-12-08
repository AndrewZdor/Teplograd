namespace :db do
  desc "Assistance for upgrading an existing database deployment"
  task :upgrade => :environment do
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:seed"].invoke
    #Rake::Task["db:proc:create"].invoke
    #Rake::Task["db:view:create"].invoke
  end
end
