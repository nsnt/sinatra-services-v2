require 'sinatra'
require 'json'
require 'mysql2'
require 'uri'

get '/env' do
  ENV['VCAP_SERVICES']
end

get '/rack/env' do
  ENV['RACK_ENV']
end

get '/' do
  'hello from sinatra'
end

get '/crash' do
  Process.kill("KILL", Process.pid)
end

not_found do
  'This is nowhere to be found.'
end

post '/rdb/:key' do
  client = load_user_provided_mysql
  value = request.env["rack.input"].read
  key = params[:key]
  result = client.query("select * from data_values where id='#{key}'")
  if result.count > 0
    client.query("update data_values set data_value='#{value}' where id='#{key}'")
  else
    client.query("insert into data_values (id, data_value) values('#{key}','#{value}');")
  end
  client.close
  value
end

get '/rdb/:key' do
  client = load_user_provided_mysql
  result = client.query("select data_value from  data_values where id = '#{params[:key]}'")
  value = result.first['data_value']
  client.close
  value
end

put '/rdb/table/:table' do
  client = load_user_provided_mysql
  client.query("create table #{params[:table]} (x int);")
  client.close
  params[:table]
end

delete '/rdb/:object/:name' do
  client = load_user_provided_mysql
  client.query("drop #{params[:object]} #{params[:name]};")
  client.close
  params[:name]
end

put '/rdb/function/:function' do
  client = load_user_provided_mysql
  client.query("create function #{params[:function]}() returns int return 1234;");
  client.close
  params[:function]
end

put '/rdb/procedure/:procedure' do
  client = load_user_provided_mysql
  client.query("create procedure #{params[:procedure]}() begin end;");
  client.close
  params[:procedure]
end

def load_user_provided_mysql
  user_provided_mysql = load_user_provided_service('cloudn-rdb')
  client = Mysql2::Client.new(:host => user_provided_mysql['host'],
                              :port => user_provided_mysql['port'].to_i, 
                              :username => user_provided_mysql['username'],
                              :password => user_provided_mysql['password'],
                              :database => user_provided_mysql['dbname'])
  result = client.query("SELECT table_name FROM information_schema.tables WHERE table_name = 'data_values'");
  client.query("Create table IF NOT EXISTS data_values ( id varchar(20), data_value varchar(20)); ") if result.count != 1
  client
end

def load_user_provided_service(service_name)
  services = JSON.parse(ENV['VCAP_SERVICES'])
  user_provided_services = services['user-provided']
  credentials = nil
  user_provided_services.each do |entry|
    if entry["name"].downcase == service_name.downcase
        credentials = entry["credentials"]
    end
  end
  return credentials
end
