module lsp::analysis;

import std::io;
import std::collections::map;

import dessert;
import derive;
import c3_parser;
import uri;

struct LspFile
{
	Uri uri;
	String text;
	int version;
}

fn LspFile* LspFile.init(&self, Allocator allocator, Uri uri, String text)
{
	self = alloc::new(allocator, LspFile, {
		.uri = uri,
		.text = text.copy(allocator),
		.version = 0,
	});
	return self;
}

macro LspFile LspFile.new(self, Allocator allocator, Uri uri, String text)
{
	self = {
		.uri = uri,
		.text = text.copy(allocator),
		.version = 0,
	};
	return self;
}

fn void LspFile.free(&self)
{
	mem::free(self.text);
	self.uri.free();
}

struct LspProject
{
	HashMap{String, LspFile} files;
	Workspace workspace;
	Allocator allocator;
}

fn void LspProject.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	self.files.init(allocator);
	self.workspace.init(allocator);
}

fn void LspProject.free(&self)
{
	self.workspace.free();
	self.files.@each(; String uri, LspFile file)
	{
		file.free();
	};
	self.files.free();
}

fn void LspProject.open_file(&self, TextDocumentItem document)
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

    if (self.files.has_key(lookup_key))
    {
        log::warn("File %s is already tracking in workspace", lookup_key);
        file_uri.free();
        return;
    }

    self.files[lookup_key] = ((LspFile){}).new(self.allocator, file_uri, document.text);

    if (catch err = parser::parse_file(&self.workspace, lookup_key))
    {   
        log::error("Parsing failure on target file: %s (Error: %s)", lookup_key, err);
    }
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

    (&self.files[lookup_key]).free();
    self.files.remove(lookup_key);
}
