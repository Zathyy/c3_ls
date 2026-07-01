module lsp::core::cache;

import derive, dessert;

import std::io;
import std::time;

const String CACHE_DIR_NAME = ".lsp-cache";

$expand(derive(MetaData::name, dessert));
struct MetaData
{
	long modified_time;
}

<*
 
*>
fn Path? get_or_create_cache_dir(String workspace_root)
{
	Path base = path::tnew(workspace_root)!;
	Path cache_dir = base.tappend(CACHE_DIR_NAME)!;

	if (!path::exists(cache_dir))
	{
		if (catch err = path::mkdir(cache_dir, recursive: true))
		{
			log::error("Failed to create cache directory: %s", cache_dir);
			return err~;
		}
	}

	return cache_dir;
}

<*
 Checks if the cached library metadata is stale compared to the raw archive file.
 @param library_name    : `e.g., lib`
 @param root_cache_path : `Path string to '.lsp-cache'`
 @param source_archive  : `Path string to the original archive file (e.g., path/to/lib.c3l)`
*>
fn bool? is_library_outdated(String library_name, String root_cache_path, String source_archive)
{
	Path cache_base = path::tnew(root_cache_path)!;
	Path lib_cache_dir = cache_base.tappend(library_name)!;

	if (!path::exists(lib_cache_dir)) return true;

	Path meta_file = lib_cache_dir.tappend("meta.json")!;
	if (!path::exists(meta_file)) return true;

	String? content = (String)file::load(tmem, meta_file);
	if (catch content) return true;

	MetaData? meta = des::deserialize{MetaData}(&&json::tdeserializer(content));
	if (catch meta) return true;

	Path src_path = path::tnew(source_archive)!;
	Time modified_time = file::last_modified(src_path)!;

	return modified_time > (Time)meta.modified_time;
}

<*
 Writes the meta.json file into the library's cache folder after successful extraction.
*>
fn void? update_library_meta(String library_name, String root_cache_path, String source_archive)
{
	Path cache_base = path::tnew(root_cache_path)!;
	Path lib_cache_dir = cache_base.tappend(library_name)!;
	Path meta_file = lib_cache_dir.tappend("meta.json")!;

	Path src_path = path::tnew(source_archive)!;
	Time src_time = file::last_modified(src_path)!;

	MetaData meta = { .modified_time = (long)src_time };

	String json_out = ser::serialize(&&json::string_serializer(), meta)!;

	if (catch file::save(meta_file, json_out))
	{
		log::error("Failed to write meta.json file for library: %s", library_name);
	}
}