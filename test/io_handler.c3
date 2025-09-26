module lsp::io_handler @test;
import lsp::msg_processor;

import std::io;

fn void read_message()
{
	io_handler::init();
	defer io_handler::quit();

	LspMessage actual = io_handler::read(mem,
		"Content-Length: 15\r\n\r\n" +++ `{"method":"hi"}`)
		?? { .method = "ERROR!" };
	defer actual.free();
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "hi");
}
fn void read_message_compound()
{
	io_handler::init();
	defer io_handler::quit();

	assert(
		@catch(io_handler::read(mem, "Content-Length: 15\r\n\r\n" +++ `{"met`))
		== io_handler::INCOMPLETE_MESSAGE);
	LspMessage actual = io_handler::read(mem, `hod":"hi"}`) ?? {
		.method = "ERROR!",
	};
	defer actual.free();
	io::printn("//");
	io::printn(actual);
	assert(actual.method == "hi");
}
