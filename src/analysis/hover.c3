module lsp::analysis::hover;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;

import std::collections::list;
import std::collections::map;

import lsp::core;

import uri;
import analyzer::core::lexer;

fn String? hover(LspProject* project, Uri uri, LspPosition pos)
{
	log::info("hover");
	Location loc = { 
		.line = (sz)pos.line,
		.column = (sz)pos.character
	};
	
	log::info("resolve - editor location: %s:%s", loc.line + 1, loc.column + 1);
	
	List{ModuleSection*} file_sections = project.workspace.find_section_by_path(uri.path);
	if (file_sections.len() == 0)
	{
		return "";
	}
	
	SourceFile* sf = file_sections.get(0).source_file;
	sz offset = sf.line_map.get_offset(sf.source, loc);

	Lexer lexer = { .buffer = sf.source, .index = 0 };
	Token? target_token = lexer.find_token_at((int)offset);
	if (catch target_token) return "";

	switch
	{
		case target_token.kind.is_keyword():
		{
			return get_keyword_docs(target_token.kind);
		}
		case target_token.kind.is_base_type():
		{
			return get_base_type_docs(target_token.kind);
		}
	}

	Cursor cursor = cursor::find_at(file_sections.get(0), (int)offset);
	if (!cursor.is_valid()) return "";

	return cursor.spelling(tmem);
}

fn String get_keyword_docs(TokenKind kind)
{
	switch (kind)
	{
		case ALIAS:      return "alias";
		case ASSERT:     return "assert";
		case ASM:        return "asm block";
		case ATTRDEF:    return "attrdef";
		case BITSTRUCT:  return "bitstruct";
		case BREAK:      return "break";
		case CASE:       return "case";
		case CATCH:      return "catch";
		case CONSTDEF:   return "constdef";
		case CONST:      return "const";
		case CONTINUE:   return "continue";
		case DEFAULT:    return "default";
		case DEFER:      return "defer";
		case DO:         return "do";
		case ELSE:       return "else";
		case ENUM:       return "enum";
		case EXTERN:     return "extern";
		case FALSE:      return "false";
		case FAULTDEF:   return "faultdef";
		case FOR:        return "for";
		case FOREACH:    return "foreach";
		case FOREACH_R:  return "foreach_r";
		case FN:         return "fn";
		case TLOCAL:     return "tlocal";
		case IF:         return "if";
		case INLINE:     return "inline";
		case IMPORT:     return "import";
		case LENGTHOF:   return "lengthof";
		case MACRO:      return "macro";
		case MODULE:     return "module";
		case NEXTCASE:   return "nextcase";
		case NULL:       return "null";
		case INTERFACE:  return "interface";
		case RETURN:     return "return";
		case STATIC:     return "static";
		case STRUCT:     return "struct";
		case SWITCH:     return "switch";
		case TRUE:       return "true";
		case TRY:        return "try";
		case TYPEDEF:    return "typedef";
		case UNION:      return "union";
		case VAR:        return "var";
		case WHILE:      return "while";
		default: unreachable();
	}
}

fn String get_base_type_docs(TokenKind kind)
{
	switch (kind)
	{
		case VOID_TYPE:           return "void";
		case BOOL_TYPE:           return "bool";
		case CHAR_TYPE:           return "char";
		case DOUBLE_TYPE:         return "double";
		case FLOAT_TYPE:          return "float";
		case FLOAT16_TYPE:        return "float16";
		case BFLOAT_TYPE:         return "bfloat";
		case INT128_TYPE:         return "int128";
		case ICHAR_TYPE:          return "ichar";
		case INT_TYPE:            return "int";
		case IPTR_TYPE:           return "iptr";
		case SZ_TYPE:             return "sz";
		case LONG_TYPE:           return "long";
		case SHORT_TYPE:          return "short";
		case UINT128_TYPE:        return "uint128";
		case UINT_TYPE:           return "uint";
		case ULONG_TYPE:          return "ulong";
		case UPTR_TYPE:           return "uptr";
		case USHORT_TYPE:         return "ushort";
		case USZ_TYPE:            return "usz";
		case FLOAT128_TYPE:       return "float128"; 
		case ANY_TYPE:            return "any";
		case FAULT_TYPE:          return "fault";
		case TYPEID_TYPE:         return "typeid";
		case UNTYPEDLIST_TYPE:    return "untypedlist";
		default: unreachable();
	}
}

