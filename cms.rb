require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

require "yaml"

require "bcrypt"

# data_path = File.expand_path(__dir__)

configure do
  enable :sessions
  set :session_secret, "87adee2f28ad318d51d500b913eea9d624ca4cce5fdf06767054198199ebfc51"
end

before do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_file(path)
  file_name = File.basename(path)
  if file_name =~ /.+\.md$/
    erb render_md(File.read(path))
  elsif file_name =~ /.+\.txt$/
    headers["Content-Type"] = "text/plain"
    File.read(path)
  end
end

def render_md(file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(file)
end

def check_user_authentication
  must_sign_in unless signed_in?
end

def signed_in?
  session.key?(:username)
end

def must_sign_in
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

get "/" do
    @files 
    erb :home, layout: :layout 
end

def signout
  session.delete(:message)
  session.delete(:username)
  session.delete(:password)
  session["message"] = "You have been signed out."

  redirect "/"
end
get "/users/signin" do

  if signed_in? 
    message = "You're already signed in as #{session[:username]}"
    session[:message] = message + " (<a href='/users/signout'>Not you?</a>)"
    redirect "/"
  end
  erb :signin, layout: :layout
end

def load_users
  users_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else 
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(users_path) # returns an array of hashes with users credentials 
end

get "/users/signup" do
  
  erb :signup, layout: :layout
end

post "/users/signup" do
  existing_users = load_users
  new_username = params[:new_username]
  if params[:new_username].empty? || params[:new_password].empty?
    session[:message] = "Fields cannot be empty."
    status 422
    erb :signup, layout: :layout
  elsif
     existing_users.key?(new_username)
    session[:message] = "Username already exists. Try <a href='/users/signin'>signing in</a>." 
    status 422
    erb :signup, layout: :layout
  else
    bcrypt_pw = BCrypt::Password.create(params[:new_password])

    File.open("users.yml", "a") do |file|
      file.puts("\n#{new_username}: #{bcrypt_pw}")
    end
    session[:username] = new_username
    session[:message] = "Welcome, #{new_username}!"
    redirect "/"
  end
end

post "/users/signin" do
  credentials = load_users
  username = params[:username]

  if credentials.key?(username) && BCrypt::Password.new(credentials[username]) == params[:password]
    session[:username] = username
    session[:message] = "Welcome, #{username}!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin, layout: :layout
  end
end

get "/users/signout" do
  signout
end

post "/users/signout" do
  session.delete(:message)
  session.delete(:username)
  session.delete(:password)
  session["message"] = "You have been signed out."

  redirect "/"
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

post "/create" do
  check_user_authentication

  @doc = params[:content]

  if  @doc.empty?
    session[:message] = "A name is required."
    status 422
    erb :new, layout: :layout
  elsif @files.include?(@doc)
    session[:message] = "Filename already in use. Try again."
    status 422
    erb :new, layout: :layout
  elsif !@doc.match?(/.+\.\w+$/)
    session[:message] = "File needs an extension."
    status 422
    erb :new, layout: :layout
  else 
    create_document(@doc)
    session[:message] = "#{@doc} has been created."
    redirect "/"
  end
end

get "/new" do
  check_user_authentication

  erb :new, layout: :layout
end

get "/:file_name" do
  file = params[:file_name]
  @path = File.join(data_path, file)

  if File.exist?(@path)
   load_file(@path)
  else
    session[:message] = "#{file} does not exist."
    redirect "/"
  end
end

post "/:file_name" do
  check_user_authentication
  
  session[:message] = "#{params[:file_name]} has been updated."
  @file = File.join(data_path, params[:file_name])
  File.write(@file, params[:content])
  redirect "/"
end


get "/:file_name/edit" do
  check_user_authentication

 "Edit #{params[:file_name]}"
 @file = params[:file_name]
 @path = File.join(data_path, @file)
 @text = File.read(@path)

 erb :edit, layout: :layout
end

post "/:file_name/delete" do
  check_user_authentication

  @file = params[:file_name]
  @path = File.join(data_path, @file)
  File.delete(@path)
  session[:message] = "#{@file} has been deleted."
  redirect "/"
end