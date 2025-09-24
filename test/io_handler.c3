module lsp::io_handler @test;

import std::io;

fn void read_message()
{
	io_handler::init();
	defer io_handler::quit();

	String expected = `{"method":"hi"}`;
	String actual = io_handler::read(mem,
		"Content-Length: 15\r\n\r\n" +++ `{"method":"hi"}`)
		?? "ERROR!";
	defer mem::free(actual);
	io::printn(expected);
	io::printn("//");
	io::printn(actual);
	assert(actual == expected);
}
fn void read_message_compound()
{
	io_handler::init();
	defer io_handler::quit();

	assert(
		@catch(io_handler::read(mem, "Content-Length: 15\r\n\r\n" +++ `{"met`))
		== io_handler::INCOMPLETE_MESSAGE);
	String expected = `{"method":"hi"}`;
	String actual = io_handler::read(mem, `hod":"hi"}`) ?? "ERROR!";
	defer mem::free(actual);
	io::printn(expected);
	io::printn("//");
	io::printn(actual);
	assert(actual == expected);
}
