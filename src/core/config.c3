module lsp::core::config;

import lsp::msg_handler::log_message;
import lsp::analysis;

import std::collections::map;
import std::collections::maybe;
import std::io;

import dessert;
import derive;
import uri;

const String PROJECT_CONFIG_NAME = "project.json";
const String MANIFEST_CONFIG_NAME = "manifest.json";

$expand(derive(ProjectConfig::name, dessert));
struct ProjectConfig
{
	String root_path @DField({ .skip = true });
	String[] sources;
	Maybe{String[]} dependency_search_paths @DField({ .rename = "dependency-search-paths" });
    Maybe{String[]} dependencies;
	Maybe{String[]} features;
	HashMap{String, TargetConfig} targets;
}

fn void ProjectConfig.free(&self, Allocator allocator)
{
	if (self.root_path) self.root_path.free(allocator);
	if (self.sources) alloc::free(allocator, self.sources);
	if (try val = self.dependency_search_paths.get())
	{
		alloc::free(allocator, val);
	} 
	if (try val = self.dependencies.get())
	{
		alloc::free(allocator, val);
	} 
	if (try val = self.features.get())
	{
		alloc::free(allocator, val);
	}

	self.targets.@each(; name, conf)
	{
		conf.free(allocator);
	};

	self.targets.free();
}

$expand(derive(ManifestConfig::name, dessert));
struct ManifestConfig
{
	String[] sources;
	HashMap{String, TargetConfig} targets;
}

fn void ManifestConfig.free(&self, Allocator alloc)
{
	if (self.sources)
	{
		alloc::free(alloc, self.sources);
	}

	self.targets.@each(; name, conf)
	{
		conf.free(alloc);
	};

	self.targets.free();
}

$expand(derive(TargetConfig::name, dessert));
struct TargetConfig
{
	Maybe{String[]} link_args;
	Maybe{String[]} dependencies;
	Maybe{String[]} linked_libraries @DField({ .rename = "linked-libraries" });
}

fn void TargetConfig.free(&self, Allocator allocator)
{
	if (try val = self.link_args.get())
	{
		alloc::free(allocator, val);
	}
	if (try val = self.dependencies.get())
	{
		alloc::free(allocator, val);
	}
	if (try val = self.linked_libraries.get())
	{
		alloc::free(allocator, val);
	}
}

fn void load(LspProject* lsp_project, WorkspaceFolder wf, Allocator allocator)
{
	Uri? uri = uri::parse(allocator, wf.uri);
	if (catch uri)
	{
		log::error("Failed to parse uri: (%s)", wf.uri);
		return;
	}
	defer {
		uri.free();
	}

	Path? root_path = path::tnew(uri.path);
	if (catch err = root_path)
	{
		log::error("Unknown workspace uri");
		return;
	}
	Path found_config;

	PathList? entries = path::ls(tmem, root_path, recursive: false, relative: true);
	if (catch entries)
	{
		log::error("Failed to list files in workspace root");
		return;
	};

	bool found_project = false;
	bool found_manifest = false;

	foreach (path : entries) 
	{
		String name = path.basename();
		if (name == PROJECT_CONFIG_NAME) found_project = true;
		if (name == MANIFEST_CONFIG_NAME) found_manifest = true;
	}
	if (!found_project && !found_manifest)
	{
		log::error("No project.json or manifest.json found in root.");
		return;
	}

	String filename = found_project ? PROJECT_CONFIG_NAME : MANIFEST_CONFIG_NAME;
    Path? config_path = root_path.tappend(filename);
	if (catch err = config_path)
	{
		log::error("Failed to append root_path with filename: %s", err);
		return;
	}
	String? json_content = (String)file::load_temp(config_path);
	if (catch err = json_content)
	{
		log::error("Failed to load file: %s", err);
		return;
	}
	log::debug("%s", json_content);
	if (found_project)
	{
		log::info("Found project.json at (%s)", config_path);
		ProjectConfig? conf = json::deserialize{ProjectConfig}(allocator, json_content);
		if (catch err = conf)
		{
			log::error("Failed to deserialize project.json - %s", err);
			return;
		}
		lsp_project.config = conf;
	} 
	else 
	{
		log::info("Found manifest in root.");
		ManifestConfig? conf = json::deserialize{ManifestConfig}(allocator, json_content);;
		if (catch err = conf)
		{
			log::error("Failed to deserialize project.json - %s", err);
			return;
		}
		lsp_project.config.sources = conf.sources;
        lsp_project.config.targets = conf.targets;
	} 

	lsp_project.config.root_path = root_path.copy(allocator);
	log::info("Set config.root_path: %s", lsp_project.config.root_path);
}	