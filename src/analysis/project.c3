module lsp::analysis;

import std::io;
import std::collections::map;

struct LspFile
{
	int version;
	String text;
}
fn usz? LspFile.to_format(&self, Formatter* f) @dynamic
	=> io::struct_to_format(*self, f, true);
fn LspFile* LspFile.init(&self, Allocator allocator, String text)
{
	self = allocator::new(allocator, LspFile, {
		.version = 0,
		.text = text.copy(allocator),
	});
	return self;
}
macro LspFile LspFile.new(self, Allocator allocator, String text)
{
	self = {
		.version = 0,
		.text = text.copy(allocator),
	};
	return self;
}
fn void LspFile.free(&self)
{
	mem::free(self.text);
}
struct LspProject
{
	// access files using URI
	inline HashMap{String, LspFile} files;
}
fn void LspProject.free(&self)
{
	self.files.@each(; String uri, LspFile file)
	{
		file.free();
	};
	self.files.free();
}
fn void LspProject.open_file(&self, String uri, String text)
{
	log::debug("opening file %s", uri);
	assert(!self.files.has_key(uri));
	self.files[uri] = ((LspFile){}).new(self.allocator, text);
}
fn void LspProject.close_file(&self, String uri)
{
	log::debug("closing file %s", uri);
	assert(self.files.has_key(uri));
	(&self.files[uri]).free();
	self.files.remove(uri);
}
