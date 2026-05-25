module lsp;

import std::collections::object;
import std::collections::maybe;

import dessert;
import derive;

$expand(derive(MessageKind::name, dessert));
enum MessageKind : char (String name) @DEnum({ .as = FIELD, .field = "name", .fallback = "UNKNOWN" })
{
	UNKNOWN      { "unknown" },
	INITIALIZE   { "initialize" },
	INITIALIZED  { "initialized" },
	DID_OPEN     { "textDocument/didOpen" },
	DID_CHANGE   { "textDocument/didChange" },
	DID_CLOSE    { "textDocument/didClose" },
	DID_SAVE     { "textDocument/didSave" },
	FULL         { "textDocument/semanticTokens/full" },
	SYMBOL       { "textDocument/documentSymbol" },
	HOVER        { "textDocument/hover" },
	COMPLETION   { "textDocument/completion" },
	DEFINITION   { "textDocument/definition" },
	DECLERATION  { "textDocument/declaration" },
	REFERENCES   { "textDocument/references" },
	HELP         { "textDocument/signatureHelp" },
	RENAME             { "textDocument/rename" },
	PREPARE_RENAME     { "textDocument/prepareRename" },
	WILL_SAVE          { "textDocument/willSave" },
	WILL_SAVE_WAIT     { "textDocument/willSaveWaitUntil" },
	FORMATTING         { "textDocument/formatting" },
	RANGE_FORMATTING   { "textDocument/rangeFormatting" },
	ON_TYPE_FORMAT     { "textDocument/onTypeFormatting" },
	CODE_ACTION        { "textDocument/codeAction" },
	CODE_LENS          { "textDocument/codeLens" },
	CODE_LENS_RESOLVE  { "textDocument/codeLens/resolve" },
	FOLDING_RANGE      { "textDocument/foldingRange" },
	SELECTION_RANGE    { "textDocument/selectionRange" },
	TYPE_DEFINITION    { "textDocument/typeDefinition" },
	IMPLEMENTATION     { "textDocument/implementation" },
	INLAY_HINT         { "textDocument/inlayHint" },
	INLAY_HINT_RESOLVE { "textDocument/inlayHint/resolve" },
	DIAGNOSTIC         { "textDocument/diagnostic" },
	SEM_TOKENS_RANGE   { "textDocument/semanticTokens/range" },
	SEM_TOKENS_DELTA   { "textDocument/semanticTokens/full/delta" },
	PREPARE_CALL_HIER  { "textDocument/prepareCallHierarchy" },
	LINKED_EDITING     { "textDocument/linkedEditingRange" },
	MONIKER            { "textDocument/moniker" },

	PUB_DIAG         { "textDocument/publishDiagnostics" },

	SHOW_MESSAGE     { "window/showMessage" },
	LOG_MESSAGE      { "window/logMessage" },
	SHOW_MSG_REQUEST { "window/showMessageRequest" },
	SHOW_DOCUMENT    { "window/showDocument" },
	WDP_CREATE       { "window/workDoneProgress/create" },
	WDP_CANCEL       { "window/workDoneProgress/cancel" },

	WS_CHANGE_CONFIG    { "workspace/didChangeConfiguration" },
	WS_CHANGE_WATCHED   { "workspace/didChangeWatchedFiles" },
	WS_CHANGE_FOLDERS   { "workspace/didChangeWorkspaceFolders" },
	WS_SYMBOL           { "workspace/symbol" },
	WS_EXECUTE_COMMAND  { "workspace/executeCommand" },
	WS_APPLY_EDIT       { "workspace/applyEdit" },
	WS_CONFIGURATION    { "workspace/configuration" },
	WS_DIAGNOSTIC       { "workspace/diagnostic" },
	WS_DIAG_REFRESH     { "workspace/diagnostic/refresh" },
	WS_SEM_REFRESH      { "workspace/semanticTokens/refresh" },
	WS_CODELENS_REFRESH { "workspace/codeLens/refresh" },
	WS_INLAY_REFRESH    { "workspace/inlayHint/refresh" },

	CALL_INCOMING    { "callHierarchy/incomingCalls" },
	CALL_OUTGOING    { "callHierarchy/outgoingCalls" },
	TYPE_SUPERTYPES  { "typeHierarchy/supertypes" },
	TYPE_SUBTYPES    { "typeHierarchy/subtypes" },

	// COMPLETION_RESOLVE { "completionItem/resolve" },

	SHUTDOWN     { "shutdown" },
	EXIT         { "exit" },
	CANCEL       { "$/cancelRequest" },
	SET_TRACE    { "$/setTrace" },
	PROGRESS     { "$/progress" },
	LOG_TRACE    { "$/logTrace" },
}

union MessageParams
{
	Object unknown;
	InitializeParams initialize;
	DidOpenParams did_open;
	DidChangeParams did_change;
	DidCloseParams did_close;
	HoverParams hover;
	CompletionParams completion;

	PublishDiagnosticsParams pub_diag;

	CancelParams cancel;
	SetTraceParams set_trace;
}

$expand(derive(InitializeParams::name, dessert));
struct InitializeParams @DStruct({ .rename_all = CAMEL_CASE })
{
	int process_id;
	struct client_info
	{
		String name;
		String version;
	}

	String locale;
	Maybe{DocumentUri} root_uri;

	Maybe{TraceKind} trace;

	Maybe{WorkspaceFolder[]} workspace_folders;
}

$expand(derive(DidOpenParams::name, dessert));
struct DidOpenParams
{
	TextDocumentItem document @DField({ .rename = "textDocument" });
}

$expand(derive(DidCloseParams::name, dessert));
struct DidCloseParams
{
	struct document @DField({ .rename = "textDocument" })
	{
		DocumentUri uri;
	}
}

$expand(derive(HoverParams::name, dessert));
struct HoverParams
{
	DocumentUri document @DField({ .rename = "textDocument/hover" });
	LspPosition position;
}

$expand(derive(CompletionParams::name, dessert));
struct CompletionParams @DStruct({ .rename_all = CAMEL_CASE })
{
	struct text_document 
	{
		String uri;
	}
	LspPosition position;
	CompletionContext context;
}

$expand(derive(PublishDiagnosticsParams::name, dessert));
struct PublishDiagnosticsParams
{
	DocumentUri uri;
	Maybe{int} version @DField({ .skip_if_empty = true });

	LspDiagnostic[] diagnostics;
}

$expand(derive(CancelParams::name, dessert));
struct CancelParams
{
	int id;
}

$expand(derive(SetTraceParams::name, dessert));
struct SetTraceParams
{
	TraceKind value;
}

$expand(derive(DidChangeParams::name, dessert));
struct DidChangeParams @DStruct({ .rename_all = CAMEL_CASE })
{
	struct text_document 
	{
		String uri;
		int version;
	}
}

