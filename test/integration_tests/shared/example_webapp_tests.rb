require 'socket'
require 'fileutils'

shared_examples_for "an example web app" do
	it "responds to GET requests for static asset" do
		FileUtils.cp('stub/garbage1.dat', @stub.full_app_root + "/public/garbage1.dat")
		get('/garbage1.dat').should == @stub.public_file('garbage1.dat')
	end

	it "supports page caching on file URIs" do
		File.write(@stub.full_app_root + "/public/cached.html", "This is the cached version of /cached")
		get('/cached').should == "This is the cached version of /cached"
	end

	it "supports page caching on directory URIs" do
		File.write(@stub.full_app_root + "/public/cached.html", "This is the cached version of /cached")
		Dir.mkdir(@stub.full_app_root + "/public/cached")
		get('/cached').should == "This is the cached version of /cached"
	end

	it "supports page caching on root/base URIs" do
		File.write(@stub.full_app_root + "/public/index.html", "This is index.html")
		get('/').should == "This is index.html"
	end

	it "doesn't use page caching if the HTTP request is not GET" do
		File.write(@stub.full_app_root + "/public/cached.html", "This is the cached version of /cached")
		post('/cached').should == "This is the uncached version of /cached"
	end

	it "responds to GET requests on dynamic pages" do
		get('/').should == "front page"
	end

	it "properly receives GET parameters" do
		result = get('/parameters?first=one&second=two')
		result.should == "Method: GET\n" +
			"First: one\n" +
			"Second: two\n"
	end

	it "responds to POST requests on dynamic pages" do
		result = post('/parameters',
			"first" => "one",
			"second" => "two"
		)
		result.should == "Method: POST\n" +
			"First: one\n" +
			"Second: two\n"
	end

	it "properly handles file uploads" do
		static_file = File.open('stub/garbage1.dat', 'rb')
		params = {
			'name1' => 'Kotonoha',
			'name2' => 'Sekai',
			'data'  => static_file
		}
		begin
			# For some reason the WSGI stub app does not accept the multipart data generated by
			# post(), so we use curl instead.
			command = "curl --silent --fail -F name1=Kotonoha -F name2=Sekai -F data=@stub/garbage1.dat " +
				"#{@server}/upload_with_params"
			response = IO.popen(command, "rb") do |io|
				io.read
			end
			response.should ==
				binary_string("name 1 = Kotonoha\n") <<
				binary_string("name 2 = Sekai\n") <<
				binary_string("data = ") << static_file.read
		ensure
			static_file.close
		end
	end

	describe "when handling POST requests with 'chunked' transfer encoding" do
		before :each do
			@uri = URI.parse(@server)
		end

		it "correctly forwards the request body to the app" do
			socket = TCPSocket.new(@uri.host, @uri.port)
			begin
				socket.write("POST #{base_uri}/raw_upload_to_file HTTP/1.1\r\n")
				socket.write("Host: #{@uri.host}:#{@uri.port}\r\n")
				socket.write("Transfer-Encoding: chunked\r\n")
				socket.write("Content-Type: text/plain\r\n")
				socket.write("Connection: close\r\n")
				socket.write("X-Output: output.txt\r\n")
				socket.write("\r\n")

				chunk = "foo=bar!"
				socket.write("%X\r\n%s\r\n" % [chunk.size, chunk])
				socket.write("0\r\n\r\n")
				socket.flush

				socket.read.should =~ /\r\nok\Z/
			ensure
				socket.close
			end

			File.read(@stub.full_app_root + "/output.txt").should == "foo=bar!"
		end

		if WEB_SERVER_DECHUNKS_REQUESTS
			it "sets Content-Length and removes Transfer-Encoding in the request" do
				socket = TCPSocket.new(@uri.host, @uri.port)
				begin
					socket.write("POST #{base_uri}/env HTTP/1.1\r\n")
					socket.write("Host: #{@uri.host}:#{@uri.port}\r\n")
					socket.write("Transfer-Encoding: chunked\r\n")
					socket.write("Content-Type: text/plain\r\n")
					socket.write("Connection: close\r\n")
					socket.write("\r\n")

					chunk = "foo=bar!"
					socket.write("%X\r\n%s\r\n" % [chunk.size, chunk])
					socket.write("0\r\n\r\n")
					socket.flush

					response = socket.read
					response.should include("CONTENT_LENGTH = 8\n")
					response.should_not include("HTTP_TRANSFER_ENCODING = ")
				ensure
					socket.close
				end
			end
		end
	end

	it "supports responses with the 'chunked' transfer encoding" do
		get('/chunked').should ==
			"chunk1\n" +
			"chunk2\n" +
			"chunk3\n"
	end

	it "supports custom headers in responses" do
		response = get_response('/extra_header')
		response["X-Foo"].should == "Bar"
	end

	it "sets the 'Status' header in responses" do
		response = get_response('/nonexistant')
		response["Status"].should == "404 Not Found"
	end

	specify "REQUEST_URI contains the request URI including query string" do
		cgi_envs = get('/env?foo=escaped%20string')
		cgi_envs.should include("REQUEST_URI = #{base_uri}/env?foo=escaped%20string\n")
	end

	specify "REQUEST_URI contains the original escaped URI" do
		cgi_envs = get('/env/%C3%BC?foo=escaped%20string')
		cgi_envs.downcase.should include("request_uri = #{base_uri}/env/%c3%bc?foo=escaped%20string\n")
	end

	specify "PATH_INFO contains the request URI without the base URI and without the query string" do
		cgi_envs = get('/env?foo=escaped%20string')
		cgi_envs.should include("PATH_INFO = /env\n")
	end

	specify "PATH_INFO contains the original escaped URI" do
		cgi_envs = get('/env/%C3%BC')
		cgi_envs.downcase.should include("path_info = /env/%c3%bc\n")
	end

	specify "QUERY_STRING contains the query string" do
		cgi_envs = get('/env?foo=escaped%20string')
		cgi_envs.should include("QUERY_STRING = foo=escaped%20string\n")
	end

	specify "QUERY_STRING must be present even when there's no query string" do
		cgi_envs = get('/env')
		cgi_envs.should include("QUERY_STRING = \n")
	end

	specify "SCRIPT_NAME contains the base URI, or the empty string if the app is deployed on the root URI" do
		cgi_envs = get('/env')
		cgi_envs.should include("SCRIPT_NAME = #{base_uri}\n")
	end

	it "appends an X-Powered-By header containing the Phusion Passenger version number" do
		response = get_response('/')
		response["X-Powered-By"].should include("Phusion Passenger")
		response["X-Powered-By"].should include(PhusionPassenger::VERSION_STRING)
	end

	it "buffers uploads" do
		get('/') # Force spawning so that the timeout below is enough.

		uri = URI.parse(@server)
		socket = TCPSocket.new(uri.host, uri.port)
		begin
			upload_data = File.read("stub/upload_data.txt")
			size_of_first_half = upload_data.size / 2

			socket.write("POST #{base_uri}/ HTTP/1.1\r\n")
			socket.write("Host: #{uri.host}:#{uri.port}\r\n")
			socket.write("Content-Type: multipart/form-data\r\n")
			socket.write("Content-Length: #{upload_data.size}\r\n")
			socket.write("Connection: close\r\n")
			socket.write("\r\n")

			socket.write(upload_data[0 .. size_of_first_half - 1])
			socket.flush

			Timeout.timeout(10) do
				get('/').should == "front page"
			end

			socket.write(upload_data[0 .. size_of_first_half])
			socket.flush
			socket.read.should =~ /front page/
		ensure
			socket.close rescue nil
		end
	end

	it "buffers any number of concurrent uploads" do
		get('/') # Force spawning so that the timeout below is enough.
		sockets = []

		uri = URI.parse(@server)
		upload_data = File.read("stub/upload_data.txt")
		size_of_first_half = upload_data.size / 2

		begin
			5.times do |i|
				log "Begin sending request #{i}"
				socket = TCPSocket.new(uri.host, uri.port)
				sockets << socket
				socket.write("POST #{base_uri}/ HTTP/1.1\r\n")
				socket.write("Host: #{uri.host}:#{uri.port}\r\n")
				socket.write("Content-Type: multipart/form-data\r\n")
				socket.write("Content-Length: #{upload_data.size}\r\n")
				socket.write("Connection: close\r\n")
				socket.write("X-Index: #{i}\r\n")
				socket.write("\r\n")
				socket.write(upload_data[0 .. size_of_first_half - 1])
				socket.flush
			end
			log "Reading front page"
			Timeout.timeout(10) do
				get('/').should == "front page"
			end
			sockets.each_with_index do |socket, i|
				log "Resuming request #{i}"
				socket.write(upload_data[size_of_first_half .. -1])
				socket.flush
				log "Completely sent request #{i}; reading response"
				content = socket.read
				if content !~ /front page/
					raise "Connection #{i} did not send a correct response:\n#{content}"
				end
			end
		ensure
			sockets.each do |socket|
				socket.close rescue nil
			end
		end
	end

	it "supports restarting via restart.txt" do
		get('/').should == "front page"
		File.write(@stub.full_app_root + "/front_page.txt", "new front page")
		File.touch(@stub.full_app_root + "/tmp/restart.txt", 2)
		get('/').should == "new front page"
	end

	it "runs as an unprivileged user" do
		get('/touch_file?file=file.txt').should == "ok"
		stat = File.stat(@stub.full_app_root + "/file.txt")
		stat.uid.should_not == 0
		stat.gid.should_not == 0
	end

	############

private
	def base_uri
		uri = URI.parse(@server)
		return uri.path.sub(%r(/$), '')
	end
end
