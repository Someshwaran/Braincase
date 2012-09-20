require 'braincase/utils'

module Braincase
  class User

    attr_reader :name, :home
    attr_accessor :email, :full_name, :groups

    def initialize(name)
      
      if name == "root"
        raise RuntimeError, "Cannot use root user"
      end

      @name=name
      @home="/home/#{name}"
      @repo="#{home}/#{name}.git"
    end

    # Build a user a line in the user_file
    def self.build(line)
      vars = line.split(":")
      
      u = self.new vars[0]
      u.email = vars[3]
      u.full_name = vars[2]
      u.groups = vars[4]

      u
    end

    def in_linux
      File.directory? @home
    end

    def set_linux_password(secret)
      
      if !Braincase.is_root?
        raise RuntimeError, "Only root is allowed to set passwords"
      end

      if !in_linux
        raise RuntimeError, "User #{@name} does not exist in linux"
      end

      pass = `openssl passwd #{secret}`.chomp
      output = `usermod -p #{pass} #{@name}`

      if $?.exitstatus != 0
        raise RuntimeError, "Unable to set password for user (#{$?.exitstatus}): #{output}"
      end

      true
    end

    def save_config

      if !has_braincase
        return false
      end

      c = { 
        [@name] => {
          full_name: @full_name,
          email: @email,
          groups: @groups
        }
      }

      File.open("#{@home}/.braincase/config","w") do {|f| f.write c.to_yaml}
    end

    def self.in_linux(name)
      File.directory? self.new(name).home
    end

    def in_dokuwiki
      begin
        return File.read(Braincase.config[:users_file]).match(/^#{user}:/)
      rescue
        return false
      end
    end

    def has_repo
      File.directory? @repo
    end

    def has_braincase
      File.directory? "#{@home}/.braincase"
    end

    def create

      add_to_linux
      setup_bare_repo
      add_userdir
      add_braincase
      add_backups
      setup_local_repo
    end

    def add_to_linux
      if !in_linux
        output = `/usr/sbin/useradd -s /bin/bash -md #{@home} #{@name} 2>&1`

        # Die unless the user was created or exists
        if $?.exitstatus != 0 and $?.exitstatus != 9
          raise RuntimeError, "Could not add user to linux (#{$?.exitstatus}): #{output}"
        end
      end
    end

    def setup_bare_repo
      if !has_repo
        run "mkdir #{@repo}"
        run "cd #{@repo} && git init --bare"
        add_hook_to_repo
      end
    end

    def setup_local_repo
      if !File.directory? "#{@home}/.git"
        run "cd ~ && git init"
        run "cd ~ && git remote add origin #{@repo}"
        run "cd ~ && git config --global user.email \"#{@email}\""
        run "cd ~ && git config --global user.name \"#{@full_name}\""
        add_ignore_file
        do_first_commit
      end
    end

    def do_first_commit
      if File.directory? "#{@home}/.git"
        run "cd ~ && git add . && git commit -m 'first commit'"
        run "cd ~ && git push origin master 2>&1 > /dev/null"
      else
        @log.error "Couldn't do the first commit as the repo wasn't created!"
      end
    end

    def add_ignore_file
      `cp /usr/share/braincase/contrib/gitignore.example #{@home}/.gitignore`
      own_file "#{@home}/.gitignore"
    end

    def add_hook_to_repo
      `cp /usr/share/braincase/contrib/post-receive.example #{@repo}/hooks`
      own_file "#{@repo}/hooks -R"
      `chmod a+x #{@repo}/hooks -R`
    end

    def own_file(file)
      `chown #{@name}:#{@name} #{file}`
    end

    def run(cmd)
      `su #{@name} -c "#{cmd}"`
    end

    def add_userdir
      if !File.directory? "#{@home}/public_html"
        run "mkdir #{@home}/public_html"
        run "touch #{@home}/public_html/.gitkeep"
      end
    end

    def add_braincase
      if !has_braincase
        run "mkdir #{@home}/.braincase"
        save_config
      end
    end

    def add_backups
      if !File.directory? "#{@home}/backups"
        run "mkdir #{@home}/backups"
      end
    end
  end
end