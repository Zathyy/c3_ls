module lsp::config;

import lsp::msg_handler::log_message;
import lsp::analysis;

import std::collections::map;
import std::io;

import dessert;
import derive;
import uri;

const String PROJECT_CONFIG_NAME = "project.json";
const String MANIFEST_CONFIG_NAME = "manifest.json";

$expand(derive(ProjectConfig::name, dessert));
struct ProjectConfig
{
	String[] sources;
	String[] dependency_search_paths @DField({ .rename = "dependency-search-paths" });
    String[] dependencies;
	String[] features;
	HashMap{String, TargetConfig} targets;
}

$expand(derive(ManifestConfig::name, dessert));
struct ManifestConfig
{
	String[] sources;
	HashMap{String, TargetConfig} targets;
}

$expand(derive(TargetConfig::name, dessert));
struct TargetConfig 
{
	String[] link_args;
	String[] dependencies;
	String[] linked_libraries @DField({ .rename = "linked-libraries" });
}

fn void load(LspProject* lsp_project, WorkspaceFolder wf, Allocator allocator)
{
	Uri? uri = uri::parse(allocator, wf.uri);
	if (catch uri)
	{
		log_message::send(string::tformat("Failed to parse uri: (%s)", wf.uri), WARNING);
		return;
	}
	defer {
		uri.free();
	}

	Path? root_path = path::tnew(uri.path);
	if (catch err = root_path)
	{
		log_message::send("Unknown workspace uri", ERROR);
		return;
	}
	Path found_config;

	PathList? entries = path::ls(allocator, root_path, recursive: false, relative: true);
	if (catch entries)
	{
		log_message::send("Failed to list files in workspace root", ERROR);
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

	if (found_project) 
	{
		log_message::send("Found project.json in root.", INFO);
	} 
	else if (found_manifest) 
	{
		log_message::send("Found manifest in root.", INFO);
	} 
	else 
	{
		log_message::send("No project.json or manifest.json found in root.", ERROR);
		return;
	}
}	