module lsp::analysis;

import analyzer::core;
import analyzer::workspace;

struct SymbolSearchResult
{
    Node* node;
    String module_name;
    bool requires_import;
}

fn SymbolSearchResult find_symbol(Workspace* ws, ModuleSection* section, String name)
{
	if (section == null) return { null, "", false };

	String current_module = section.parent_module.name;

    Node* local_match = ws.lookup_in_module(current_module, name) ?? null;
    if (local_match != null)
    {
        return { local_match, current_module, false };
    }

	foreach (imp : section.nodes)
    {
		if (imp.kind != IMPORT_DECL) continue;

		ImportDecl* imp_decl = imp.as(IMPORT_DECL);

		foreach (path : imp_decl.paths)
		{
			PathExpr* path_expr = path.as(PATH_EXPR);
			if (try full_path = path_expr.full_path(&section.source_file.ast.string_pool, tmem))
			{
				Node* imported_match = ws.lookup_in_module(full_path, name) ?? null;
				if (imported_match != null)
				{
					return { imported_match, full_path, false };
				}
			}
		}
    }

	ws.modules.@each(; mod_name, mod)
	{
		if (mod_name != current_module)
		{
			Node* external_match = ws.lookup_in_module(mod.name, name) ?? null;
			if (external_match != null)
			{
				return { external_match, mod.name, true };
			}
		}
	};

    return { null, "", false };
}
