module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;
import std::collections::set;

import lsp::core;
import uri;						
import analyzer::core::lexer;

fn void provide_module_paths(Context* ctx, List{CompletionItem}* items)
{
	String current_mod = ctx.section.parent_module.name;
	HashSet{String} added_segments;

	ctx.ws.modules.@each(; name, mod)
	{
		do SCOPE:
		{
			if (name == current_mod) break SCOPE;

			String remaining_path = get_remaining_path(name, ctx.base_identifier, ctx.access);
			if (remaining_path.len == 0 && ctx.access == LspAccessKind.STATIC)
			{
				break SCOPE; 
			}

			String next_segment = get_next_segment(remaining_path);

			if (ctx.prefix.len > 0 && !next_segment.starts_with(ctx.prefix))
			{
				break SCOPE;
			}

			if (added_segments.contains(next_segment))
			{
				break SCOPE;
			}
			
			added_segments.add(next_segment);

			bool is_leaf = (next_segment == remaining_path);
			
			items.push({
				.label = next_segment,
				.kind = MODULE,
				.detail = is_leaf ? "Module" : "Namespace",
				.sort_text = string::tformat("0020_%s", next_segment)
			});
		};
	};
}

fn String get_remaining_path(String name, String base_id, LspAccessKind access)
{
	if (access != LspAccessKind.STATIC || base_id.len == 0)
	{
		return name;
	}

	String root_marker = string::tformat("%s::", base_id);
	String nested_marker = string::tformat("::%s::", base_id);

	if (name.starts_with(root_marker))
	{
		return name[root_marker.len : name.len - root_marker.len];
	}

	if (name.len >= nested_marker.len)
	{
		for (sz i = 0; i <= name.len - nested_marker.len; i++)
		{
			if (name[i : nested_marker.len] == nested_marker)
			{
				sz offset = i + nested_marker.len;
				return name[offset : name.len - offset];
			}
		}
	}

	return "";
}

fn String get_next_segment(String remaining_path)
{
	if (remaining_path.len < 2) return remaining_path;

	for (sz i = 0; i < remaining_path.len - 1; i++)
	{
		if (remaining_path[i : 2] == "::")
		{
			return remaining_path[0 : i];
		}
	}
	return remaining_path;
}