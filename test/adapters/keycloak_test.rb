# frozen_string_literal: true
require 'test_helper'

class KeycloakTest < ActiveSupport::TestCase
  test 'new' do
    assert Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')
  end

  test 'endpoint' do
    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')

    assert_kind_of URI, keycloak.endpoint
  end

  test 'setting access token' do
    subject = Keycloak.new('http://lvh.me:3000')

    subject.access_token = 'sometoken'

    assert_equal 'sometoken', subject.send(:access_token).token
  end

  test 'endpoint normalization' do
    uri = URI('http://lvh.me:3000/auth/realm/name/')

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name').endpoint

    assert_equal uri,
                 Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name/').endpoint
  end

  test 'timeout error' do
    stub_request(:post, 'http://lvh.me:3000/auth/realm/name/protocol/openid-connect/token').to_timeout

    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name')

    begin
      keycloak.test
    rescue Keycloak::AuthenticationError => error
      assert_kind_of Faraday::TimeoutError, error.cause
      assert error.bugsnag_meta_data.presence
    end
  end

  test 'test' do
    form_urlencoded = { 'Content-Type'=>'application/x-www-form-urlencoded' }
    token = stub_request(:post, 'http://example.com/auth/realm/name/protocol/openid-connect/token').
        with(
            body: {'client_id' => 'id', 'client_secret' => 'secret', 'grant_type' => 'client_credentials'},
            headers: form_urlencoded).
        to_return(status: 200, body: 'access_token=foo', headers: form_urlencoded)
    well_known = stub_request(:get, "http://example.com/auth/realm/name/.well-known/openid-configuration").
        to_return(status: 200)
    keycloak = Keycloak.new('http://id:secret@example.com/auth/realm/name')

    keycloak.test

    assert_requested token
    assert_requested well_known
  end

  test 'invalid response error' do
    stub_request(:get, 'http://lvh.me:3000/auth/realm/name/.well-known/openid-configuration').
        to_return(status: 200, body: 'somebody', headers: {'Content-Type' => 'text/plain'} )

    keycloak = Keycloak.new('http://id:secret@lvh.me:3000/auth/realm/name', access_token: 'something')

    assert_raises Keycloak::InvalidResponseError do
      keycloak.test
    end
  end

  test 'using configuration' do
    config = {
        attributes: {
            serviceAccountsEnabled: true
        }
    }.deep_stringify_keys

    Rails.application.config.x.stub(:keycloak, config) do
      client = Keycloak::Client.new(name: 'foo')

      assert_includes client.to_h, :serviceAccountsEnabled
    end
  end

  test 'client hash' do
    client = Keycloak::Client.new(name: 'name')

    assert_includes client.to_h, :name
  end

  test 'client serialization' do
    client = Keycloak::Client.new(name: 'name')

    assert_equal client.to_h.to_json, client.to_json
  end

  test 'oauth flows' do
    keycloak = { clientId: "client_id", implicitFlowEnabled: true, serviceAccountsEnabled: true }

    assert_equal keycloak, Keycloak::Client.new({
                                                    id: 'client_id',
                                                    oidc_configuration: {
                                                        implicit_flow_enabled: true,
                                                        service_accounts_enabled: true,
                                                    }
                                                }).to_h.slice(*keycloak.keys)
  end
end
