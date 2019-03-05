require_relative 'docker_service'

module Pygmy
  class Traefik
    extend Pygmy::DockerService

    def self.image_name
      'containous/traefik'
    end

    def self.container_name
      'traefik.docker.amazee.io'
    end

    def self.network_name
      'amazeeio-network'
    end

    def self.connect_cmd
      "docker network connect #{self.network_name} #{self.container_name}"
    end

    def self.connected?
      !!(Pygmy::DockerNetwork.inspect_containers(self.network_name) =~ /#{self.container_name}/)
    end

    def self.connect
      unless self.connected?
        unless Sh.run_command(self.connect_cmd).success?
          raise RuntimeError.new(
              "Failed to connect #{self.container_name} to #{self.network_name}.  Command #{self.connect_cmd} failed"
          )
        end
      end
      self.connected?
    end

    def self.run_cmd
      "docker run -d " \
      "-p 80:80 -p 8080:8080 -p 443:443 " \
      "--restart always " \
      "--volume=/var/run/docker.sock:/var/run/docker.sock " \
      "--name=#{Shellwords.escape(self.container_name)} " \
      "--label traefik.frontend.rule=Host:#{Shellwords.escape(self.container_name)} " \
      '--label traefik.docker.network=amazeeio-network ' \
      "#{Shellwords.escape(self.image_name)} " \
      "--api --docker " \
      "'--docker.domain=docker.amazee.io ' \"
    end

  end
end
