require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

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

def signed_in?
  session[:username] == "admin" && session[:password] == "secret"
end

get "/" do
  if signed_in? 
    @files 
    erb :home, layout: :layout 
  else 
    status 302
    redirect "/users/signin"
  end
end

get "/users/signin" do

  erb :signin, layout: :layout
end

post "/users/signin" do

  if params[:username] == "admin" && params[:password] == "secret"
    session[:username] = params[:username]
    session[:password] = params[:password]
    session[:message] = "Welcome, #{session[:username]}!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin, layout: :layout
  end
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
  session[:message] = "#{params[:file_name]} has been updated."
  @file = File.join(data_path, params[:file_name])
  File.write(@file, params[:content])
  redirect "/"
end


get "/:file_name/edit" do
 "Edit #{params[:file_name]}"
 @file = params[:file_name]
 @path = File.join(data_path, @file)
 @text = File.read(@path)

 erb :edit, layout: :layout
end

post "/:file_name/delete" do
  @file = params[:file_name]
  @path = File.join(data_path, @file)
  File.delete(@path)
  session[:message] = "#{@file} has been deleted."
  redirect "/"
end