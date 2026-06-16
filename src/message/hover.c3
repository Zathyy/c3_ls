<*
	https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_hover
*>
module lsp::msg_handler::hover;
import lsp::translator;

import std::io;
import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;
import lsp::io_handler;

import lsp::analysis;
import uri;

enum HoverContentKind
{
    MARKED_STRING,
    MARKED_STRING_ARRAY,
    MARKUP_CONTENT
}

union MarkupContentUnion
{
	MarkedString marked_string;
	MarkedString[] marked_string_array;
	MarkupContent markup_content;
}

$expand(derive(LspHoverResponse::name, dessert::serialize));
struct LspHoverResponse @DStruct({ .rename_all = CAMEL_CASE })
{	
	String jsonrpc;
	int id;

	struct result 
	{
		HoverContentKind content_kind @DField({ .skip = true });
		MarkupContentUnion contents @DField({ .tagged = { .by = "content_kind", .inlined = true } });
		<*
		An optional range is a range inside a text document
		that is used to visualize a hover, e.g. by changing the background color.
	*>
		Maybe{LspRange} range;
	}
}

$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities @DStruct({ .rename_all = CAMEL_CASE })
{
	bool dynamic_registration;
	MarkupKind[] content_format;
}

fn void response(Allocator allocator, LspProject* project, LspMessage* message)
{
	log::warn("URI: %s", message.params.hover.document.uri);
	Uri? file_uri = uri::parse(tmem, message.params.hover.document.uri);
	
	if (catch err = file_uri)
	{
		log::error("Failed to parse uri: %s", err);
		return;
	}
	LspPosition pos = message.params.hover.position;

	String? hover = hover::hover(project, file_uri, pos);
	if (catch err = hover)
	{
		log::error("Failed to hover : %s", err);
		return;
	}

	LspHoverResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.result = {
			.content_kind = MARKUP_CONTENT,
			.contents = {
				.markup_content = {
					.kind = PLAIN_TEXT,
					.value = hover,
				},
			},
		}
	};
	String response_json = translator::encode(response, allocator);

	log::debug("Hover response: %s", response_json);
	io_handler::write(response_json);
}
