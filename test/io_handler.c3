module lsp::io_handler @test;
import lsp::translator;

import std::io;

fn void read_message()
{
	io_handler::init();
	defer io_handler::quit();

	LspMessage actual = io_handler::read(mem,
		"Content-Length: 43\r\n\r\n" +++ `{"jsonrpc":"2.0","method":"hi","params":{}}`)
		?? { .method = "ERROR!" };
	defer actual.free();
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "hi");
	assert(actual.rpc == "2.0");
}
fn void read_message_compound()
{
	io_handler::init();
	defer io_handler::quit();

	assert(
		@catch(io_handler::read(mem, "Content-Length: 43\r\n\r\n"
			+++ `{"jsonrpc":"2.0","met`))
		== translator::INCOMPLETE_JSON
	);
	LspMessage actual = io_handler::read(mem, `hod":"hi","params":{}}`) ?? {
		.method = "ERROR!",
	};
	defer actual.free();
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "hi");
	assert(actual.rpc == "2.0");
}
fn void read_multiple_messages()
{
	log::set_priority_all(LogPriority.VERBOSE);
	io_handler::init();
	defer io_handler::quit();

	String message = 
		"Content-Length: 43\r\n\r\n" +++ `{"jsonrpc":"2.0","method":"hi","params":{}}` +++
		"Content-Length: 46\r\n\r\n" +++ `{"jsonrpc":"41.52","method":"bye","par`;

	LspMessage actual = io_handler::read(mem, message) ?? { .method = "ERROR!" };
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "hi");
	assert(actual.rpc == "2.0");
	actual.free();

	/// splitting the message is necessary in order for the function to read
	/// only from the message param
	actual = io_handler::read(mem, `ams":{}}`) ?? { .method = "ERROR!" };
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "bye");
	assert(actual.rpc == "41.52");
	actual.free();
}
