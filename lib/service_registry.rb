require 'singleton'
require 'json'

# Defining state constants
module State
  UP=1
  DOWN=2
  WARNING=3
end

module HelperMethods
  # Checks if all hosts are up
  def all_hosts_up?(hosts)
    hosts.each do |host|
      return false unless
          status_data['hosts'].has_key?(host) and
              status_data['hosts'][host]['current_state'] == 0
    end

    true
  end

  def host_up?(host)
    status_data['hosts'].has_key?(host) and
        status_data['hosts'][host]['current_state'] == 0
  end

  def host_flapping?(host)
    status_data['hosts'].has_key?(host) and
        status_data['hosts'][host]['is_flapping'] != 0
  end

  # Checks if the service is up
  def service_up?(host, service)
    status_data['services'].has_key?(host) and
        status_data['services'][host].has_key?(service) and
        status_data['services'][host][service]['current_state'] == 0
  end

  def service_flapping?(host, service)
    status_data['services'].has_key?(host) and
        status_data['services'][host].has_key?(service) and
        status_data['services'][host][service]['is_flapping'] != 0
  end

  def default(host, service = nil)
    if service == nil
      if host_flapping? host
        State::WARNING
      elsif host_up? host
        State::UP
      else
        State::DOWN
      end
    else
      if service_flapping? host, service
        State::WARNING
      elsif service_up? host, service
        State::UP
      else
        State::DOWN
      end
    end
  end
end

class ServiceRegistry
  CACHE_SECONDS = 600
  StatusSource = File.join(File.dirname(__FILE__), '..', 'data', 'status.json')

  include Singleton
  include HelperMethods

  def initialize
  end

  def service(name, &block)
    @services[name] = block.call
  end

  def services
    update?
    @services
  end

  def status_data
    update?
    @status_data
  end

  def update!
    @services = {}
    @status_data = JSON.parse(File.read(StatusSource))
    load(File.join(File.dirname(__FILE__), '..', 'data', 'services.rb'))
    @load_date = DateTime.now
  end

  private
  def update?
    if ((DateTime.now - @load_date) * 60 * 60 * 24).to_i > CACHE_SECONDS
      update!
    end
  end
end

def Services(&block)
  ServiceRegistry.instance.instance_eval(&block)
end
