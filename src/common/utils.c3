module lsp::utils;

import std::io;
import std::collections;

fn bool? sf_walk_callback(Path path, bool is_dir, void* data) @private
{
	log::info("Walking: %s", path);
    if (is_dir) return false;
    List{String}* paths = (List{String}*)data;
    if (path.has_extension("c3i") || path.has_extension("c3"))
    {
        paths.push(path.copy(tmem));
    }
    
    return false;
}

fn String[] find_source_files(Allocator allocator, Path base_path, bool with_c3i = true)
{
	List{String} paths; paths.init(allocator);
    
    if (catch err = base_path.walk(&sf_walk_callback, &paths))
    {
        log::error("Failed to walk source_files: %s", err);
    }

    return paths.array_view();
}

