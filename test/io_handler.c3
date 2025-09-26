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
	assert(actual.rpc == "2.0");
	assert(actual.method == "hi");
}
fn void read_message_compound()
{
	io_handler::init();
	defer io_handler::quit();

	assert(
		@catch(io_handler::read(mem, "Content-Length: 43\r\n\r\n" +++ `{"jsonrpc":"2.0","met`))
		== translator::INCOMPLETE_JSON);
	LspMessage actual = io_handler::read(mem, `hod":"hi","params":{}}`) ?? {
		.method = "ERROR!",
	};
	defer actual.free();
	io::printn("//");
	io::printn(actual);
	assert(actual.rpc == "2.0");
	assert(actual.method == "hi");
}
