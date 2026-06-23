module lsp::analysis;

import std::io;
import std::collections::map;

import lsp::msg_handler::publish_diag;
import lsp::config;
import dessert;
import derive;
import analyzer::core;
import analyzer::workspace;
import uri;

struct LspFile
{
	Uri uri;
	String text;
	int version;
}

fn void LspFile.free(&self)
{
	mem::free(self.text);
	self.uri.free();
}

struct LspProject
{
	HashMap{String, LspFile*} files;
	Workspace workspace;
	ProjectConfig config;
	HashMap{String, ManifestConfig} manifests;
	Allocator allocator;
}

fn void LspProject.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	self.files.init(allocator);
	self.workspace.init(allocator, { .use_sema = true });
}

fn void LspProject.free(&self)
{
	self.workspace.free();
	self.files.@each(; String uri, LspFile* file)
	{
		file.free();
		alloc::free(self.allocator, file);
	};
	self.files.free();
}

fn void LspProject.open_file(&self, TextDocumentItem document, bool is_std_lib = false)
{
	String raw_uri = document.uri;

	log::debug("Registering document stream via raw tracking token: %s", raw_uri);


	Uri? file_uri = uri::parse(self.allocator, raw_uri);
	if (catch err = file_uri) 
	{
		log::error("Malformed URI received (%s)", raw_uri);
		return;
	};

	String lookup_key = file_uri.path;
	log::warn("Opening file: %s", lookup_key);

	if (self.files.has_key(lookup_key))
	{
		log::warn("File %s is already tracking in workspace", lookup_key);
		file_uri.free();
		return;
	}
	
	LspFile* lsp_file = alloc::new(self.allocator, LspFile);
	*lsp_file = { 
		.uri = file_uri, 
		.text = document.text.copy(self.allocator),
		.version = 1,
	};

	self.files[lookup_key] = lsp_file;

	FileInput file;

	if (!is_std_lib)
	{
		file = {
			.source_text = lsp_file.text,
			.uri = lookup_key,
		};
	}
	else
	{
		file = {
			.path = lookup_key,
			.uri = lookup_key,
		};
	}

	ProcessResult? result = result = workspace::process(&self.workspace, self.allocator, file);
	if (catch err = result)
	{   
		log::error("Parsing failure on target file: %s (Error: %s)", lookup_key, err);
		return;
	}
	defer result.free();

	publish_diag::publish(self.allocator, file_uri, &result);
}

fn void LspProject.change_file(&self, DidChangeParams params)
{
	String raw_uri = params.document.uri;
	log::debug("Registering document stream via raw tracking token: %s", raw_uri);

	Uri? file_uri = uri::parse(tmem, raw_uri);
	if (catch err = file_uri) 
	{
		log::error("Malformed URI received (%s)", raw_uri);
		return;
	};

	String lookup_key = file_uri.path;

	if (!self.files.has_key(lookup_key))
	{
		log::warn("File %s is not already tracking in workspace", lookup_key);
		return;
	} 

	LspFile* file = self.files.get(lookup_key) ?? null;
	if (!file) return;

	if (file.text.ptr != null)
	{
		mem::free(file.text); 
	}

	file.text = params.content_changes[0].text.copy(self.allocator);
	FileInput input = {
		.source_text = file.text,
		.uri = lookup_key
	};
	ProcessResult? result = result = workspace::process(&self.workspace, self.allocator, input);
	if (catch err = result)
	{   
		log::error("Parsing failure on target file: %s (Error: %s)", lookup_key, err);
		return;
	}
	defer result.free();

	publish_diag::publish(self.allocator, file.uri, &result);
}

fn void LspProject.close_file(&self, DocumentUri document)
{
	String raw_uri = document;
	Uri? query_uri = uri::parse(tmem, raw_uri);
	if (catch query_uri) return;

	String lookup_key = query_uri.path;

	log::debug("Deregistering file: %s", lookup_key);

	if (!self.files.has_key(lookup_key))
	{
		log::error("Attempted to drop non-existent file path identifier (%s)", lookup_key);
		return;
	}

	LspFile* file = self.files.get(lookup_key) ?? null;
	if (!file) return;

	file.free();
	alloc::free(self.allocator, file);
	self.files.remove(lookup_key);
}
