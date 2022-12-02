ENV["RACK_ENV"] = "test"


require "minitest/autorun"
require "rack/test"


require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => {username: "admin", password: "secret"}}
  end
  
  def test_home_signed_out
    get "/"

    assert_equal 302, last_response.status
  end

  def test_home_signed_in
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_view_document
    create_document "changes.txt", "This is a sample text..."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This is a sample text..."
  end

  def test_file_not_found

    get "/nonexistent.txt"

    assert_equal 302, last_response.status
    
    get last_response["location"]

    assert_equal 302, last_response.status 
    assert_equal "nonexistent.txt does not exist.", session[:message]

    # get "/"
    # refute_includes last_response.body, "nonexistent.txt does not exist."
  end

  def test_view_markdown
    create_document("markdown.md", "# Heading in Markdown")
    get "/markdown.md"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h1>Heading in Markdown</h1>"
  end

  def test_edit_document
    create_document("about.md")
    get "/about.md/edit"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %(<button type="submit")
  end

  def test_update_document
  
    post "/about.md", content: "# A markdown heading."

    assert_equal 302, last_response.status

    get last_response["location"]

    assert_equal "about.md has been updated.", session[:message]

    get "/about.md"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h1>A markdown heading.</h1>"
  end

  def test_new_document_form
    get "/new"

    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %(<button type="submit")
    assert_equal 200, last_response.status
  end

  def test_create_new_document

    post "/create", content: "teste.md"
    assert_equal 302, last_response.status

    assert_equal "teste.md has been created.", session[:message]
  
     get last_response["location"]
     get last_response["location"] 
     assert_equal 200, last_response.status
    assert_includes last_response.body, "teste.md"
  end

  def test_create_name_in_use
    create_document("file.txt")

    post "/create", content: "file.txt"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Filename already in use."
  end

  def test_create_without_name

    post "/create", content: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"

  end

  def test_delete_button
    
    create_document("test.txt")

    post "/test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["location"]
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_signin_page
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome, admin!", session[:message]

    get last_response["location"]

    assert_includes last_response.body, "Welcome, admin"
    assert_includes last_response.body, "Signed in as admin"
  end
end