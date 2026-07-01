module lsp::core;

import std::io;
import std::collections::map;
import std::collections::list;

import std::compression::zip;

import lsp::analysis;
import lsp::msg_handler::publish_diag;
import lsp::core::config;
import dessert;
import derive;
import analyzer::core;
import analyzer::workspace;
import uri;
import lsp::utils;

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
	List{FileInput} process_queue;
	Workspace workspace;
	ProjectConfig config;
	HashMap{String, ManifestConfig} manifests;
	Allocator allocator;
}

fn void LspProject.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	self.files.init(allocator);
	self.process_queue.init(allocator);
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
	self.process_queue.free();
	self.config.free(self.allocator);
	self.manifests.@each(; name, conf)
	{
		conf.free(self.allocator);
	};
	self.manifests.free();
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

	self.process_queue.push(file);
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

	if (params.document.version <= file.version) return;
	file.version = params.document.version;
	log::info("Reindexing: version = %d", file.version);

	if (file.text)
	{
		mem::free(file.text); 
	}
	file.text = params.content_changes[0].text.copy(self.allocator);
	FileInput input = {
		.source_text = file.text,
		.uri = lookup_key
	};
	self.process_queue.push(input);
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

fn void LspProject.update(&self)
{
	if (self.process_queue.is_empty()) return;

	FileInput[] files = self.process_queue.array_view();
	defer self.process_queue.clear();
	ProcessResult? result = result = workspace::process_batch(&self.workspace, self.allocator, files);
	if (catch err = result)
	{   
		log::error("Parsing failure (Error: %s)", err);
		return;
	}
	defer result.free();
	publish_diag::publish(self.allocator, files, &result);
}

fn void LspProject.initial_process(&self)
{
	self.process_stdlib();
	self.process_config();
	self.process_libs();
}

fn void LspProject.process_stdlib(&self)
{

}

fn void LspProject.process_config(&self)
{
	Path? base_path = path::tnew(self.config.root_path);
	if (catch err = base_path)
	{
		log::error("Config base path is not valid.");
		return;
	}

	log::error("base_path: %s", base_path);

	foreach (source_entry : self.config.sources)
	{
		String entry_str = source_entry;
		bool recursive = false;
		String mask = "*.c3";

		if (entry_str.ends_with("/**"))
		{
			entry_str = entry_str.strip_suffix("/**");
			recursive = true;
		}

		Path? entry_path = base_path.tappend(entry_str);
		if (catch err = entry_path)
		{
			log::error("'%s' is not a valid directory layout: %s", entry_str, err);
			continue;
		}

		log::error("Entry: %s", entry_path);
		
		PathList paths;
		if (catch err = @try(paths, path::ls(tmem, entry_path, no_dirs: true, mask: mask, recursive: recursive, rebase: entry_path)))
		{
			log::error("Failed to list directory contents for: %s", entry_str);
			continue;
		}

		foreach (matched : paths)
		{
			log::info("Found path: %s", matched);
			Uri file_uri = uri::from_file_path(tmem, matched);
			DocumentUri uri = (DocumentUri)file_uri.to_raw_string(tmem);
			self.open_file({ .uri = uri }, true);
		}
	}
}

fn void LspProject.process_libs(&self)
{
	Path? base_path = path::tnew(self.config.root_path);
	if (catch err = base_path)
	{
		log::error("Config base path is not valid for parsing libraries.");
		return;
	}

	String[] deps = self.config.dependencies.get() ?? {};
	foreach (dep_name : deps)
	{
		String lib_target_name = string::tformat("%s.c3l", dep_name);
		bool lib_found = false;

		String[] search_paths = self.config.dependency_search_paths.get() ?? {};
		foreach (search_entry : search_paths)
		{
			Path? search_base = base_path.tappend(search_entry);
			if (catch search_base) continue;

			Path? lib_path = search_base.tappend(lib_target_name);
			if (catch lib_path) continue;

			if (!path::exists(lib_path)) continue;

			lib_found = true;
			Path scan_target = lib_path; 
			bool is_compressed = path::is_file(lib_path);

			if (is_compressed)
			{
				if (lib_path.has_extension("c3i"))
				{
					log::debug("Found a declaration file (.c3i) at: %s", lib_path);
					
				}	
				else
				{
					log::debug("Found a compressed library archive (.c3l file) at: %s", lib_path);
					
					Path? cache_root = cache::get_or_create_cache_dir(self.config.root_path);
					if (catch cache_root) continue;
					Path? cache_target_dir = cache_root.tappend(dep_name);
					if (catch cache_target_dir) continue;
					if (catch cache::is_library_outdated(dep_name, cache_target_dir, lib_path))
					{
						log::info("Cache is stale or missing for %s. Extracting...", dep_name);
						
						if (path::exists(cache_target_dir))
						{
							(void)path::rmtree(cache_target_dir);
						}
						if (catch err = path::mkdir(cache_target_dir, recursive: true))
						{
							log::error("Failed to create cache_target dir: %s", err);
							continue;
						}
						
						if (decompress_library(lib_path, cache_target_dir))
						{
							if (catch err = cache::update_library_meta(dep_name, cache_root, lib_path))
							{
								log::error("Failed to update meta file: %s", err);
							}
						}
					}
					else 
					{
						log::info("Cache hit for library %s. No offline modifications detected.", dep_name);
					}
					
					scan_target = cache_target_dir;
				}
			}
			else
			{
				log::info("Found an uncompressed library folder (.c3l folder) at: %s", lib_path);
			}



			String[] paths = utils::find_source_files(tmem, lib_path);

			foreach (matched : paths)
			{
				log::info("Found internal library source: %s", matched);
				Uri file_uri = uri::from_file_path(tmem, matched);
				DocumentUri uri = (DocumentUri)file_uri.to_raw_string(tmem);
				self.open_file({ .uri = uri }, true);
			}

			break;
		}
	}
}

<*
 Extracts a zipped library archive to a target cache directory.
 @param source_archive  : `Path to the .c3l / .zip file (e.g., "libs/glfw.c3l")`
 @param cache_target_dir: `Path to the destination directory (e.g., ".lsp-cache/glfw")`
*>
fn bool decompress_library(String source_archive, Path cache_target_dir)
{
    log::info("Extracting archive %s to %s", source_archive, cache_target_dir);

    ZipArchive? archive = zip::open(tmem, source_archive, "r");
    if (catch err = archive)
    {
        log::error("Failed to open zip archive: %s", source_archive);
        return false;
    }

    if (catch err = archive.extract(cache_target_dir))
    {
        log::error("Extraction failed for %s", source_archive);
        (void)archive.close();
        return false;
    }

    (void)archive.close();
    return true;
}