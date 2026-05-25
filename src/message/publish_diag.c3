module lsp::msg_handler::publish_diag;

import std::collections::list;

import c3_parser::parser::error;
import lsp::io_handler;
import lsp::translator;
import dessert;
import derive;

import uri;

$expand(derive(MessageSeverity::name, dessert));
constdef MessageSeverity : inline int
{
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	HINT = 4,
}

$expand(derive(LspDiagnostic::name, dessert));
struct LspDiagnostic 
{
	LspRange range;
	MessageSeverity severity;
	String message;
	String source;
}

fn void publish(Allocator allocator, Parser* parser)
{
	List{LspDiagnostic} diags;
	diags.tinit();

	foreach (err : parser.errors)
	{
		diags.push({
			.range = {
				.start = { .line = (uint) err.loc.line, .character = (uint) err.loc.column },
				.end = { .line = (uint) err.loc.line, .character = (uint) err.loc.column + err.token.len },
			},
			.severity = (MessageSeverity) err.level,
			.message = err.message,
			.source = "c3-parser"
		});
	}

	LspMessage res = {
		.rpc = "2.0",
		.method = PUB_DIAG,
		.params.pub_diag = {
			.uri = (DocumentUri) string::tformat("file://%s", parser.file_path),
			.diagnostics = diags.to_tarray(),
		}
	};

	String response_json = translator::encode(res, allocator);

	log::debug("complete response: %s", response_json);
	io_handler::write(response_json);
}
