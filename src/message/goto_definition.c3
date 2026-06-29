<*
	https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_definition
*>
module lsp::msg_handler::goto_definition;
import lsp::translator;
import lsp::core;

import std::io;
import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;
import lsp::io_handler;

import lsp::analysis;
import uri;

$expand(derive(LspGoToDefinitionResponse::name, dessert::serialize));
struct LspGoToDefinitionResponse @DStruct({ .rename_all = CAMEL_CASE })
{	
	String jsonrpc;
	int id;

	LspLocation[] result;
}

$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities @DStruct({ .rename_all = CAMEL_CASE })
{
	bool dynamic_registration;
	bool link_support;
}

fn void response(Allocator allocator, LspProject* project, LspMessage* message)
{
	log::warn("URI: %s", message.params.definition.document.uri);
	Uri? file_uri = uri::parse(tmem, message.params.definition.document.uri);
	
	if (catch err = file_uri)
	{
		log::error("Failed to parse uri: %s", err);
		return;
	}
	LspPosition pos = message.params.definition.position;

	LspLocation[]? definitions = goto_definition::goto_definition(project, file_uri, pos);
	if (catch err = definitions)
	{
		log::error("Failed to go to definition : %s", err);
		return;
	}

	LspGoToDefinitionResponse response = {
		.jsonrpc = message.rpc,
		.id = message.id.get() ?? -1,
		.result = definitions
	};
	String response_json = translator::encode(response, allocator);

	log::debug("Goto definition response: %s", response_json);
	io_handler::write(response_json);
}
