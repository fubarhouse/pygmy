require_relative 'docker_service'

module Pygmy
  class Traefik
    extend Pygmy::DockerService

    # Image to be used for service.
    def self.image_name
      'traefik:2.0'
    end

    # Identifying name for container.
    def self.container_name
      'traefik.docker.amazee.io'
    end

    # Network for Traefik to target.
    def self.network_name
      'amazeeio-network'
    end

    # Domain suffix for services.
    def self.domain
      'docker.amazee.io'
    end

    # Pattern to be used for services.
    def self.host
      "Host(`{{ .Name }}.#{self.domain}`)"
    end

    # The command used to connect to the network.
    def self.connect_cmd
      "docker network connect #{self.network_name} #{self.container_name}"
    end

    # Identify if the service is connected.
    def self.connected?
      !!(Pygmy::DockerNetwork.inspect_containers(self.network_name) =~ /#{self.container_name}/)
    end

    # Connect the service to the nominated network.
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

    # The command to execute for creation via docker.
    def self.run_cmd
      "docker run -d " \
      "-p 80:80 -p 8080:8080 -p 443:443 " \
      "--restart always " \
      "--volume=/var/run/docker.sock:/var/run/docker.sock " \
      "--name=#{Shellwords.escape(self.container_name)} " \
      '--label traefik.docker.network=amazeeio-network ' \
      "#{Shellwords.escape(self.image_name)} " \
      "--api --providers.docker " \
      "--providers.docker.defaultrule=#{Shellwords.escape(self.host)} "
    end

  end
end
