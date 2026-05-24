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

enum HoverContentKind
{
    MARKED_STRING,
    MARKED_STRING_ARRAY,
    MARKUP_CONTENT
}

union MarkupContentUnion @DUnion({ .inlined = true })
{
	MarkedString marked_string;
	MarkedString[] marked_string_array;
	MarkupContent markup_content;
}

$expand(derive(LspHoverResponse::name, dessert::serialize));
struct LspHoverResponse @DStruct({ .rename_all = CAMEL_CASE })
{	
	HoverContentKind content_kind @DField({ .skip = true });
   	MarkupContentUnion contents @DField({ .tagged_by = "content_kind" });
	<*
		An optional range is a range inside a text document
	 	that is used to visualize a hover, e.g. by changing the background color.
	*>
	Maybe{LspRange} range;
}

$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities @DStruct({ .rename_all = CAMEL_CASE })
{
	bool dynamic_registration;
	MarkupKind[] content_format;
}

fn void response(Allocator allocator, LspMessage* message)
{
	LspHoverResponse response = {
		.content_kind = MARKED_STRING,
		.contents = {
			.marked_string = {

			},
		},
	};
	String response_json = translator::encode(response, allocator);

	log::debug("Hover response: %s", response_json);
	io_handler::write(response_json);
}
