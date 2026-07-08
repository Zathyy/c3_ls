module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

<*
 check for '.' or '::'
*>
fn void detect_access_context(Context* ctx)
{
	ctx.access = NONE;
	ctx.base_identifier = "";

	if (ctx.tokens.len() < 2) return;

	sz op_idx = -1;
	for (sz i = 0; i < ctx.tokens.len(); i++)
	{
		// If this token starts at or past the cursor, the operator must be the previous one
		if (ctx.tokens[i].pos >= ctx.offset)
		{
			op_idx = i - 1;
			break;
		}
	}
	// If the cursor is at the very end of the file, the operator is the last token
	if (op_idx == -1) op_idx = ctx.tokens.len() - 1;
	if (op_idx < 1) return; // Need at least an identifier + operator
	Token op_tok = ctx.tokens[op_idx];
	if (op_tok.kind == DOT || op_tok.kind == SCOPE)
	{
		// Ensure the token right before it is the base identifier
		Token base_tok = ctx.tokens[op_idx - 1];
		switch (base_tok.kind)
		{
			case IDENT:
			case TYPE_IDENT:
			case HASH_IDENT:
			case AT_IDENT:
				ctx.access = (op_tok.kind == SCOPE) ? LspAccessKind.STATIC : LspAccessKind.INSTANCE;
				String src = ctx.section.source_file.source;
				ctx.base_identifier = src[base_tok.pos:base_tok.len];
				ctx.base_offset = base_tok.pos;		
			default:
				break;
		}
	}
}

<*
 @returns "true if this consumed the completion (context locked to member access)"
*>
fn bool provide_member_access(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access == NONE || ctx.base_identifier.len == 0) return false;
	switch (ctx.access)
	{
		// resolve '::' with a order of
		// (ident) locals & params -> module path
		// (type_ident) TypeResolution
		case STATIC:
		{
			provide_module_paths(ctx, items);
			
			SemaScope* leaf = sema::find_deepest_scope(&ctx.section.scope, (int)ctx.offset);

			if (ctx.base_identifier.len > 0)
			{
				if (try SemaVar sema_var = leaf.find_variable(ctx.base_identifier))
				{
					log::debug("Resolved '%s' to local variable", ctx.base_identifier);
					return provide_type_static_completions(ctx, items, sema_var.def);
				}
			}

			List{SemaVar} symbols = sema::collect_visible_symbols(tmem, leaf, (int)ctx.offset);
			foreach (entry : symbols)
			{
				Cursor var_cursor = { .node = entry.def };
				if ((var_cursor.spelling(tmem) ?? "") == ctx.base_identifier)
				{
					log::debug("Base identifier '%s' resolved to local variable instance");
					return provide_type_static_completions(ctx, items, entry.def);
				}
			}

			Module* target_mod = null;
			String current_module_name = ctx.section.parent_module.name;
			String path_suffix = string::tformat("::%s", ctx.base_identifier);

			log::debug("curent_module_name: %s", current_module_name);
			log::debug("path_suffix: %s", path_suffix);
			
			ctx.ws.modules.@each(; mod_name, mod)
			{
				do MOD_SEARCH:
				{
					log::debug("comparing: %s against %s", ctx.base_identifier, mod_name);
					if (mod_name == ctx.base_identifier)
					{
						target_mod = mod;
						break MOD_SEARCH;
					}

					if (current_module_name.len > 0)
					{
						String combined_path = string::tformat("%s::%s", current_module_name, ctx.base_identifier);
						if (mod_name == combined_path)
						{
							target_mod = mod;
							break MOD_SEARCH;
						}
					}
					log::debug("comparing (ends_with): %s against %s", path_suffix, mod_name);
					if (mod_name.len >= path_suffix.len)
					{
						sz suffix_start = mod_name.len - path_suffix.len;
						bool is_suffix_match = true;

						for (sz i = 0; i < path_suffix.len; i++)
						{
							if (mod_name[suffix_start + i] != path_suffix[i])
							{
								is_suffix_match = false;
								break MOD_SEARCH;
							}
						}
						
						if (is_suffix_match)
						{
							log::debug("Suffix match successful for: %s", mod_name);
							target_mod = mod;
							break MOD_SEARCH;
						}
					}
				};
			};

			if (target_mod)
			{
				log::debug("Resolved module scope via path cascade: %s", target_mod.name);
				
				target_mod.symbols.@each(; symbol_name, symbol_list)
				{
					do CHECK:
					{
						if (symbol_list.is_empty()) break CHECK;
						if (ctx.prefix.len > 0 && !symbol_name.contains(ctx.prefix)) break CHECK;

						foreach (entry : symbol_list)
						{
							if (entry.node.visibility != PUBLIC) continue;
							if (entry.node.kind == MODULE_DECL || entry.node.kind == IMPORT_DECL) continue;

							add_symbol_completion(ctx, items, symbol_name, entry.node, ctx.base_identifier);
						}
					};
				};
				
				return true;
			}

			List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(ctx.base_identifier);
			if (catch candidates) return false;
			if (candidates.len() == 0) return false;
			if (!candidates[0].node) return false;;

			Node* target_node = candidates[0].node;

			// Otherwise, it's a Type Resolution (e.g., MyStruct::, int::)
			log::debug("Base identifier '%s' resolved to type kind: %s", ctx.base_identifier, target_node.kind);
			analysis::inject_type_properties(ctx, items, target_node.kind);
			return true;
		}
		case INSTANCE:
		{
			log::debug("acess: %s", "instance");
			
			SemaScope* leaf = sema::find_deepest_scope(&ctx.section.scope, (int)ctx.offset);
			Node* var_def = null;

			log::debug("Cursor at %d, leaf scope range is [%d:%d]", 
		   	ctx.offset, leaf.range.start, leaf.range.end);
			
			if (ctx.base_identifier.len > 0)
			{
				if (try SemaVar sema_var = leaf.find_variable(ctx.base_identifier))
				{
					log::debug("Resolved '%s' to local variable", ctx.base_identifier);
					var_def = sema_var.def;
				}
				else
				{
					log::debug("Could not find variable '%s' in scope", ctx.base_identifier);
					return false;
				}
			}
			else
			{
				List{SemaVar} symbols = sema::collect_visible_symbols(tmem, leaf, (int)ctx.offset);
				foreach (var_entry : symbols)
				{
					Cursor var_cursor = { .node = var_entry.def };
					log::debug("var spelling: %s", var_cursor.spelling(tmem) ?? "");
					if ((var_cursor.spelling(tmem) ?? "") == ctx.base_identifier)
					{
						var_def = var_entry.def;
						break;
					}
				}
			}

			if (!var_def)
			{
				log::debug("Could not find local variable declaration for: %s", ctx.base_identifier);
				return false;
			}
		
			Cursor type_cursor = { var_def.as(VarDecl).type };
			String type_spelling = type_cursor.raw_type_identifier() ?? "";

			log::debug("Checking for type: %s", type_spelling);

			List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(type_spelling);
			if (catch candidates) return false;
			if (candidates.len() == 0) return false;
			if (!candidates[0].node) return false;
			
			log::debug("found candidate: %s", candidates[0].node.kind);

			if (candidates[0].node.kind == STRUCT_DECL)
			{
				StructDecl* str_decl = candidates[0].node.as(StructDecl);
				foreach (field_node : str_decl.fields)
				{
					if (field_node.kind != VAR_DECL) continue;
					VarDecl* field = field_node.as(VarDecl);

					Cursor field_cursor = { field_node };
					String field_name = field_cursor.spelling(tmem) ?? "";

					Cursor field_type_cursor = { field.type };
					String field_type_name = field_type_cursor.spelling(tmem) ?? "";

					if (ctx.prefix.len > 0 && !field_name.contains(ctx.prefix)) continue;
					
					items.push({
						.label = field_name,
						.kind = FIELD,
						.detail = field_type_name
					});
				}
			}
			
			ctx.ws.modules.@each(; name, mod)
			{
				mod.registry.methods.@each(; MethodKey key, List{SymbolEntry} list)
				{
					if COND: (key.type_name == ctx.base_identifier) 
					{
						if (ctx.prefix.len > 0 && !key.method_name.contains(ctx.prefix)) break COND;

						foreach (entry : list) 
						{
							items.push({
								.label = key.method_name,
								.kind = METHOD,
								.detail = string::tformat("method of %s", ctx.base_identifier)
							});
							break;
						}

					}
				};
			};
			
			return true;
		}	


		default:
	}
	
	return false;
}

fn bool provide_type_static_completions(Context* ctx, List{CompletionItem}* items, Node* var_def)
{
	Cursor type_cursor = { var_def };
	String type_spelling = type_cursor.raw_type_identifier() ?? "";
	if (type_spelling.len == 0) return false;

	List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(type_spelling);
	if (catch candidates) return false;
	if (candidates.len() == 0) return false;
	if (!candidates[0].node) return false;

	log::debug("Injecting reflection properties for instance variable type: %s", type_spelling);
	analysis::inject_type_properties(ctx, items, candidates[0].node.kind);
	return true;
}