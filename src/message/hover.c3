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

$expand(derive(LspHoverRequest::name, dessert));
struct LspHoverRequest
{
	inline LspRequest request;
	LspHoverParams params;
}

$expand(derive(LspHoverParams::name, dessert));
struct LspHoverParams
{
	DocumentUri document @DField({ .rename = "textDocument" });
	<* The position inside the text document. *>
	LspPosition position;
} 

fn LspHoverRequest? parse_message(LspMessage message)
{
	LspHoverRequest self = {
		.request = msg_handler::get_request_struct(message)!,
	};

  	log::info(ser::serialize(&&json::string_serializer(), &self)!!);

	return self;
}

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

$expand(derive(LspHoverResponse::name, dessert));
struct LspHoverResponse
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
struct LspServerCapabilities
{
	bool dynamic_registration @DField({ .rename = "dynamicRegistration" });
	MarkupKind[] content_format @DField({ .rename = "contentFormat" });
}

fn String LspHoverRequest.response(&self, Allocator allocator)
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
	return response_json;
}
