require 'json'

require_relative 'uaa_resource'

class User < UAAResource
  attr_reader :email, :google_id, :cf_admin

  def initialize(obj)
    @email = obj.fetch('email')
    @google_id = obj.fetch('google_id')
    @cf_admin = obj.fetch('cf_admin', false)
  end

  def exists?(uaa_client)
    begin
      get_user(uaa_client)
    rescue StandardError
      return false
    end
    true
  end

  def create(uaa_client)
    resp = uaa_client['/Users'].post({
      emails: [{ value: @email }],
      origin: 'google',
      userName: @google_id
    }.to_json)
    resp.code == 201
  end

  def get_user(uaa_client)
    scim_filter = [
      'origin+eq+"google"',
      "userName+eq+\"#{@google_id}\""
    ].join('+and+')
    get_resource("/Users?filter=#{scim_filter}", uaa_client)
  end
end
