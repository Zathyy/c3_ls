module lsp::translator @test;

import std::collections::pair;
import std::io;
import dessert;
import derive;

$expand(derive(TranslatorTest::name, dessert));
struct TranslatorTest
{
	String method;
	int hello;
	struct this_is {
		bool working;
		String well;
		struct uhh {
			int i_guess;
		}
	}
}

fn void encode_message()
{
	TranslatorTest encoded = {
		.method = "idk",
		.hello = 21,
		.this_is = {
			.working = true,
			.well = "yes it is",
			.uhh.i_guess = 314159,
		}
	};
	io::printn(encoded);
	String expected = "Content-Length: 98\r\n\r\n" +++ `{"method":"idk","hello":21,"this_is":{"working":true,"well":"yes it is","uhh":{"i_guess":314159}}}`;
	io::printn(expected);
	String actual = translator::encode(encoded, tmem);
	io::printn(actual);
	assert(actual == expected);
}

fn void decode_message()
{
	String decoded = "Content-Length: 43\r\n\r\n" +++ `{"jsonrpc":"2.0","method":"initialized","params":{}}`;
	IoDecodeResult actual = translator::decode(mem, decoded)!!;
	defer actual.message.free();
	io::printn("//");
	io::printn(actual.message);
	assert(actual.message.rpc == "2.0");
	assert(actual.message.method == INITIALIZED);
}
