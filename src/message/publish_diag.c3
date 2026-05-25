module lsp::msg_handler::publish_diag;

import c3_parser::parser::error;
import lsp::io_handler;
import lsp::translator;
import dessert;
import derive;

import uri;

$expand(derive(MessageSeverity::name, dessert));
constdef MessageSeverity
{
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	LOG = 4,
	DEBUG = 5,
}

$expand(derive(LspDiagnostic::name, dessert));
struct LspDiagnostic 
{
	LspRange range;
	MessageSeverity severity;
	String message;
	String source;
}

fn void publish(Allocator allocator, ParserError[] parser_errors)
{
	LspMessage res = {
	};

	String response_json = translator::encode(res, allocator);

	log::debug("complete response: %s", response_json);
	io_handler::write(response_json);
}
