module Sprinkle
  module Actors
    class Script < Dummy

      @installed = []
      class << self; attr_accessor :installed; end
      class << self; attr_accessor :installing; end

      def directory d='./tmp'
        @directory ||= d
      end

      def file f=File.open("#{@directory}/install.sh", 'w+')
        @file ||= f
      end

      def initialize &block
        @roles={}
        self.instance_eval(&block)
        defaults
      end

      def defaults
        directory unless @directory
        FileUtils.mkdir directory rescue true
        file unless @file
      end

      def install(installer, roles, opts={})
        @installer = installer
        process(@installer.package, @installer.install_sequence, roles, opts)
      end

      def process(name, commands, roles, opts = {})
        return true if Script.installed.include? @installer
        Script.installed  << @installer unless @installer.nil?

        unless commands.empty?
          case @installer
          when Sprinkle::Installers::Source, Sprinkle::Installers::Binary
            commands = download_handler @installer
          when Sprinkle::Installers::Transfer, Sprinkle::Installers::FileInstaller
            commands = transfer_handler @installer
          when Sprinkle::Installers::Reconnect
            # Not much can be done about this
            puts "ERR: Can't handle #{commands}"
            return
          when Sprinkle::Installers::Runner, Sprinkle::Installers::PushText
            # just write the out, nothing to handle
          else
            puts "ERR: Can't handle #{commands}"
            return
          end

          if Script.installing != @installer.package
            Script.installing = @installer.package
            print; print "# #{@installer.package}"
          end

          commands.each do |cmd|
            print_command cmd
          end
        end

        true
      end

      def download_handler installer
        commands = []
        file = installer.instance_exec { @binary_archive }

        download_file file, directory
        commands << %Q[#{installer.extract_command} '#{installer.archive_name}' -C #{installer.prefix}]
        pre, post = pre_post installer

        pre + commands + post
      end

      def download_file file
        `wget -cq --directory-prefix=#{directory} #{file}`
      end

      def transfer_handler installer
        commands = []
        if installer.respond_to? :contents
          source = installer.instance_eval { @file.path }
        else
          source = installer.source
        end

        copy source
        commands << %Q[cp #{source.split('/').last} #{installer.destination}]
        pre, post = pre_post installer
        pre + commands + post
      end

      def copy file
        `cp #{file} #{directory}`
      end

      def mute; end;
      def print line=''; file.puts line; end
      def print_command cmd
        if cmd.respond_to? :string
          c = cmd.string
        else
          c = %Q[bash -c "#{escape cmd}"]
        end
        return if c.nil?
        file.print c
        file.print "\n"
      end

      private
      def escape c
        c.gsub(%q[\n], %q[\\n]).gsub(%q["], %q[\"]).gsub(%q[$], %q[\$])
      end
      def pre_post installer
        pre = installer.instance_eval { pre_commands(:install) }
        post = installer.instance_eval { post_commands(:install) }
        [pre, post]
      end

    end
  end
end

